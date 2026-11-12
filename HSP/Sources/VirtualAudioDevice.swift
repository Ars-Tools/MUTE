import AVFAudio
import func Accelerate.vDSP_mmov
import func Accelerate.vDSP_mmovD
import typealias Accelerate.vDSP_Length
import AudioToolbox
import Auxiliary
import CoreAudio
import CoreAudio.AudioServerPlugIn
import CoreFoundation
import Darwin
import Dispatch
import Foundation
import os
import Synchronization

// The HAL ABI is imported directly from Apple's explicit CoreAudio submodule.
// No bridging header, Objective-C implementation, or C translation unit is needed.
@usableFromInline
enum ObjectID {
    @usableFromInline
    static let plugin: AudioObjectID = AudioObjectID(kAudioObjectPlugInObject)
    @usableFromInline
    static let device: AudioObjectID = 3
    @usableFromInline
    static let input: AudioObjectID = 4
    @usableFromInline
    static let output: AudioObjectID = 8
}
public enum Access {
    case ReadOnly
    case Writable
}

/// Device identity, supported PCM formats, and input rendering supplied by the application.
/// Identity and supported formats must remain stable for the lifetime of the HAL device.
/// auInternalRenderBlock is called outside I/O for each selected format.
/// Formats describe the render block's PCM layout; HAL streams use the same
/// sample representation and rate, interleaved. HSP interleaves planar output.
/// The returned block follows the AUInternalRenderBlock contract.
public protocol VirtualAudioInputDeviceProtocol: Sendable {
    var name: String { get }
    var manufacturer: String { get }
    var bundleIdentifier: String { get }
    var uid: String { get }
    var modelUID: String { get }
    var inputStreamName: String { get }
    var outputStreamName: String { get }
    var formats: Array<AVAudioFormat> { get }
    var timestampPeriod: UInt32 { get }

    /// Reports access to additional properties; nil means unsupported.
    func HasProperty(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>
    ) -> Optional<Access>

    /// Returns bytes written, or required capacity without writing when too small.
    func GetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifier: UnsafeRawBufferPointer, data: UnsafeMutableRawBufferPointer
    ) throws -> Int

    /// Accept the complete property value or throw without partially applying it.
    func SetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifier: UnsafeRawBufferPointer, data: UnsafeRawBufferPointer
    ) throws -> Int

    func auInternalRenderBlock(
        format: AVAudioFormat, maximumFramesToRender: AUAudioFrameCount
    ) -> AUInternalRenderBlock
}

extension VirtualAudioInputDeviceProtocol {
    public var inputStreamName: String { "Input" }
    public var outputStreamName: String { "Discard Output" }
    public var timestampPeriod: UInt32 { 16_384 }

    public func HasProperty(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>
    ) -> Optional<Access> {
        .none
    }
}

@usableFromInline
struct VirtualAudioDeviceRenderState {
    let block: (UnsafePointer<AudioTimeStamp>, UInt32, UnsafeMutableRawPointer) -> OSStatus

    init(format: AVAudioFormat, maximumFramesToRender: AUAudioFrameCount, render: @escaping AUInternalRenderBlock) {
        let channels: UInt32 = format.channelCount
        let bytesPerFrame: Int = Int(halStreamDescription(format).mBytesPerFrame)
        precondition(Int(maximumFramesToRender) <= Int(UInt32.max) / bytesPerFrame)
        // Choose the complete buffer adapter once, while I/O is stopped.
        switch (format.commonFormat, format.isInterleaved) {
        case (.pcmFormatFloat64, false):
            block = planarInputRenderBlock(Double.self, channels: channels,
                maximumFramesToRender: maximumFramesToRender, render: render,
                copy: { vDSP_mmovD($0, $1, 1, vDSP_Length($2), 1, vDSP_Length($3)) })
        case (.pcmFormatFloat32, false):
            block = planarInputRenderBlock(Float.self, channels: channels,
                maximumFramesToRender: maximumFramesToRender, render: render,
                copy: { vDSP_mmov($0, $1, 1, vDSP_Length($2), 1, vDSP_Length($3)) })
        case (.pcmFormatInt16, false):
            block = planarInputRenderBlock(Int16.self, channels: channels,
                maximumFramesToRender: maximumFramesToRender, render: render)
        case (.pcmFormatInt32, false):
            block = planarInputRenderBlock(Int32.self, channels: channels,
                maximumFramesToRender: maximumFramesToRender, render: render)
        case (.pcmFormatFloat64, true), (.pcmFormatFloat32, true),
             (.pcmFormatInt16, true), (.pcmFormatInt32, true):
            block = { time, frames, buffer in
                let byteCount: Int = Int(frames) * bytesPerFrame
                guard time.pointee.mFlags.contains(.sampleTimeValid), time.pointee.mSampleTime.isFinite else {
                    memset(buffer, 0, byteCount)
                    return kAudioHardwareIllegalOperationError
                }
                var output: AudioBufferList = AudioBufferList(mNumberBuffers: 1,
                    mBuffers: AudioBuffer(mNumberChannels: channels, mDataByteSize: UInt32(byteCount), mData: buffer))
                var flags: AudioUnitRenderActionFlags = []
                let status: OSStatus = render(&flags, time, frames, 0, &output, nil, nil)
                guard status == noErr else { return status }
                if flags.contains(.unitRenderAction_OutputIsSilence) {
                    memset(buffer, 0, byteCount)
                    return noErr
                }
                guard output.mNumberBuffers == 1, output.mBuffers.mNumberChannels == channels,
                      output.mBuffers.mDataByteSize >= UInt32(byteCount),
                      let rendered: UnsafeMutableRawPointer = output.mBuffers.mData
                else { return kAudioHardwareIllegalOperationError }
                if rendered != buffer { memmove(buffer, rendered, byteCount) }
                return noErr
            }
        default:
            preconditionFailure("Unsupported PCM format")
        }
    }
}

/// Adapt the application's planar PCM to the single interleaved HAL stream buffer.
/// All storage is allocated at construction, and each call restores the ABL fields
/// because AUInternalRenderBlock may replace its buffers or report silence.
private func planarInputRenderBlock<Sample>(
    _ sample: Sample.Type, channels: UInt32, maximumFramesToRender: AUAudioFrameCount,
    render: @escaping AUInternalRenderBlock,
    copy: @escaping (UnsafePointer<Sample>, UnsafeMutablePointer<Sample>, Int, Int) -> Void = {
        for frame: Int in 0..<$2 { $1[frame * $3] = $0[frame] }
    }
) -> (UnsafePointer<AudioTimeStamp>, UInt32, UnsafeMutableRawPointer) -> OSStatus {
    let channelCount: Int = Int(channels)
    let capacity: Int = Int(maximumFramesToRender)
    let bytesPerSample: Int = MemoryLayout<Sample>.stride
    let scratch: Autorelease.Object<UInt8> = Autorelease.Object<UInt8>(
        object: UnsafeMutableRawPointer.allocate(byteCount: capacity * channelCount * bytesPerSample,
            alignment: MemoryLayout<Sample>.alignment).assumingMemoryBound(to: UInt8.self)) { $0.deallocate() }
    let buffers: Autorelease.Object<AudioBufferList> = Autorelease.Object<AudioBufferList>(
        object: AudioBufferList.allocate(maximumBuffers: channelCount).unsafeMutablePointer) { free($0) }
    let busy: Atomic<Bool> = Atomic<Bool>(false)
    return { time, frames, buffer in
        let byteCount: Int = Int(frames) * bytesPerSample
        let totalBytes: Int = byteCount * channelCount
        guard time.pointee.mFlags.contains(.sampleTimeValid), time.pointee.mSampleTime.isFinite else {
            memset(buffer, 0, totalBytes)
            return kAudioHardwareIllegalOperationError
        }
        // The prepared storage has one writer. Reject overlapping invocations
        // without blocking or spinning instead of racing its ABL and sample data.
        guard busy.compareExchange(expected: false, desired: true, ordering: .acquiring).exchanged else {
            return kAudioUnitErr_CannotDoInCurrentContext
        }
        defer { busy.store(false, ordering: .releasing) }
        buffers.reference.pointee.mNumberBuffers = channels
        let output: UnsafeMutableAudioBufferListPointer = UnsafeMutableAudioBufferListPointer(buffers.reference)
        for channel: Int in 0..<channelCount {
            output[channel] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(byteCount),
                mData: UnsafeMutableRawPointer(scratch.reference.advanced(by: channel * capacity * bytesPerSample)))
        }
        var flags: AudioUnitRenderActionFlags = []
        let status: OSStatus = render(&flags, time, frames, 0, buffers.reference, nil, nil)
        guard status == noErr else { return status }
        if flags.contains(.unitRenderAction_OutputIsSilence) {
            memset(buffer, 0, totalBytes)
            return noErr
        }
        guard buffers.reference.pointee.mNumberBuffers == channels else { return kAudioHardwareIllegalOperationError }
        // Validate every plane before writing any of the HAL buffer.
        for channel: Int in 0..<channelCount {
            guard output[channel].mNumberChannels == 1,
                  output[channel].mDataByteSize >= UInt32(byteCount), output[channel].mData != nil
            else { return kAudioHardwareIllegalOperationError }
        }
        let target: UnsafeMutablePointer<Sample> = buffer.assumingMemoryBound(to: Sample.self)
        for channel: Int in 0..<channelCount {
            let source: UnsafePointer<Sample> = UnsafeRawPointer(output[channel].mData!).assumingMemoryBound(to: Sample.self)
            // Copy one matrix column: source row stride 1, target row stride channels.
            copy(source, target.advanced(by: channel), Int(frames), channelCount)
        }
        return noErr
    }
}

/// HSP exposes one interleaved PCM buffer per HAL stream, independent of AU layout.
@inlinable
@_transparent
func halStreamDescription(_ format: AVAudioFormat) -> AudioStreamBasicDescription {
    var result: AudioStreamBasicDescription = format.streamDescription.pointee
    if !format.isInterleaved {
        result.mFormatFlags &= ~kAudioFormatFlagIsNonInterleaved
        result.mBytesPerFrame *= result.mChannelsPerFrame
        result.mBytesPerPacket *= result.mChannelsPerFrame
    }
    return result
}

@inlinable
@_transparent
func sameStreamDescription(_ a: AudioStreamBasicDescription, _ b: AudioStreamBasicDescription) -> Bool {
    a.mSampleRate == b.mSampleRate && a.mFormatID == b.mFormatID && a.mFormatFlags == b.mFormatFlags
        && a.mBytesPerPacket == b.mBytesPerPacket && a.mFramesPerPacket == b.mFramesPerPacket
        && a.mBytesPerFrame == b.mBytesPerFrame && a.mChannelsPerFrame == b.mChannelsPerFrame
        && a.mBitsPerChannel == b.mBitsPerChannel
}

/// Adapts an application-defined input device to HAL properties, transactions, and clock.
/// Copies share the same control/clock state and active render block.
public struct VirtualAudioDevice<Device: VirtualAudioInputDeviceProtocol>: AudioServerPlugInDriverInterfaceProtocol {
    public let device: Device
    /// DSP capacity, independent of HAL's current I/O buffer size.
    public let maximumFramesToRender: AUAudioFrameCount
    public var name: String { device.name }
    public var manufacturer: String { device.manufacturer }
    public var bundleIdentifier: String { device.bundleIdentifier }
    public var uid: String { device.uid }
    public var modelUID: String { device.modelUID }
    public var inputStreamName: String { device.inputStreamName }
    public var outputStreamName: String { device.outputStreamName }
    public var formats: Array<AVAudioFormat> { device.formats }
    public var timestampPeriod: UInt32 { device.timestampPeriod }
    // HAL serializes stopped-I/O configuration against rendering. Keep the
    // active block shared between copies without acquiring a render-time lock.
    private let renderState: Autorelease.Object<VirtualAudioDeviceRenderState>

    public var format: AVAudioFormat { stateLock.withLockUnchecked(\.currentFormat) }

    @usableFromInline
    struct ControlState {
        @usableFromInline
        var currentFormat: AVAudioFormat
        @usableFromInline
        var host: AudioServerPlugInHostRef?
        @usableFromInline
        var runningClients: UInt64 = 0
        @usableFromInline
        var inputActive: UInt32 = 1
        @usableFromInline
        var outputActive: UInt32 = 1
    }

    @usableFromInline
    struct ClockState: Sendable {
        @usableFromInline
        var anchorHost: UInt64
        @usableFromInline
        var sampleRate: Double
        @usableFromInline
        var running: Bool = false
        @usableFromInline
        var seed: UInt64 = 1
    }

    @usableFromInline
    let stateLock: OSAllocatedUnfairLock<ControlState>
    @usableFromInline
    let clockLock: OSAllocatedUnfairLock<ClockState>
    private let ticksPerSecond: Double

    /// The first format is initially active. Formats may use either PCM layout,
    /// with the same channel count and finite positive sample rates.
    public init(device: Device, maximumFramesToRender: AUAudioFrameCount) {
        precondition(maximumFramesToRender > 0)
        self.device = device
        self.maximumFramesToRender = maximumFramesToRender
        let formats: Array<AVAudioFormat> = device.formats
        precondition(!formats.isEmpty)
        let initial: AVAudioFormat = formats[0]
        precondition(
            formats.allSatisfy {
                $0.commonFormat != AVAudioCommonFormat.otherFormat
                    && $0.streamDescription.pointee.mBytesPerFrame > 0
                    && Int($0.streamDescription.pointee.mBytesPerFrame)
                        <= Int(UInt32.max) / Int($0.isInterleaved ? 1 : max(1, $0.channelCount))
                    && $0.channelCount == initial.channelCount && $0.channelCount > 0
                    && $0.sampleRate.isFinite && $0.sampleRate > 0
            })
        precondition(device.timestampPeriod > 0)
        stateLock = OSAllocatedUnfairLock<ControlState>(uncheckedState: ControlState(currentFormat: initial))
        clockLock = OSAllocatedUnfairLock<ClockState>(
            initialState: ClockState(
                anchorHost: mach_absolute_time(), sampleRate: initial.sampleRate))
        renderState = Autorelease.Object<VirtualAudioDeviceRenderState>(object: UnsafeMutablePointer<VirtualAudioDeviceRenderState>.allocate(capacity: 1)) {
            $0.deinitialize(count: 1)
            $0.deallocate()
        }
        renderState.reference.initialize(to: VirtualAudioDeviceRenderState(
            format: initial, maximumFramesToRender: maximumFramesToRender,
            render: device.auInternalRenderBlock(format: initial, maximumFramesToRender: maximumFramesToRender)))
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        ticksPerSecond = 1e9 * Double(info.denom) / Double(info.numer)
    }

    @inlinable
    @_transparent
    func resetClock(sampleRate: Double, running: Bool) {
        // Caller holds stateLock. Lock order is always state -> clock.
        clockLock.withLock { clock in
            clock.anchorHost = mach_absolute_time()
            clock.sampleRate = sampleRate
            clock.running = running
            clock.seed &+= 1
        }
    }

    @inlinable
    @_transparent
    func notify(_ object: AudioObjectID, _ addresses: Array<AudioObjectPropertyAddress>) {
        guard let host: AudioServerPlugInHostRef = stateLock.withLockUnchecked(\.host) else { return }
        addresses.withUnsafeBufferPointer {
            _ = host.pointee.PropertiesChanged(host, object, UInt32($0.count), $0.baseAddress!)
        }
    }

    public func CreateDevice(
        description: CFDictionary, client: UnsafePointer<AudioServerPlugInClientInfo>,
        result: UnsafeMutablePointer<AudioObjectID>
    ) -> OSStatus {
        kAudioHardwareUnsupportedOperationError
    }

    public func DestroyDevice(object: AudioObjectID) -> OSStatus {
        kAudioHardwareUnsupportedOperationError
    }

    public func Initialize(host: AudioServerPlugInHostRef) -> OSStatus {
        stateLock.withLockUnchecked { $0.host = host }
        return noErr
    }

    public func AddDeviceClient(
        object: AudioObjectID, client: UnsafePointer<AudioServerPlugInClientInfo>
    ) -> OSStatus {
        object == ObjectID.device ? noErr : kAudioHardwareBadObjectError
    }

    public func RemoveDeviceClient(
        object: AudioObjectID, client: UnsafePointer<AudioServerPlugInClientInfo>
    ) -> OSStatus {
        object == ObjectID.device ? noErr : kAudioHardwareBadObjectError
    }

    public func PerformDeviceConfigurationChange(
        object: AudioObjectID, action: UInt64, info: UnsafeMutableRawPointer?
    ) -> OSStatus {
        guard object == ObjectID.device else { return kAudioHardwareBadObjectError }
        let state: VirtualAudioDevice<Device> = self
        // Configuration actions identify a complete advertised format, including sample width.
        guard action > 0, action <= UInt64(state.formats.count) else {
            return kAudioHardwareIllegalOperationError
        }
        let formatIndex: Int = Int(action - 1)
        let changed: Bool = state.stateLock.withLock { control in
            guard control.runningClients == 0 else { return false }
            let format: AVAudioFormat = state.formats[formatIndex]
            control.currentFormat = format
            state.renderState.reference.pointee = VirtualAudioDeviceRenderState(
                format: format, maximumFramesToRender: state.maximumFramesToRender,
                render: state.device.auInternalRenderBlock(format: format, maximumFramesToRender: state.maximumFramesToRender))
            state.resetClock(sampleRate: format.sampleRate, running: false)
            return true
        }
        guard changed else { return kAudioHardwareIllegalOperationError }
        state.notify(ObjectID.device, [AudioObjectPropertyAddress(selector: kAudioDevicePropertyNominalSampleRate)])
        let formats: Array<AudioObjectPropertyAddress> = [
            AudioObjectPropertyAddress(selector: kAudioStreamPropertyVirtualFormat),
            AudioObjectPropertyAddress(selector: kAudioStreamPropertyPhysicalFormat),
        ]
        state.notify(ObjectID.input, formats)
        state.notify(ObjectID.output, formats)
        return noErr
    }

    public func AbortDeviceConfigurationChange(
        object: AudioObjectID, action: UInt64, info: UnsafeMutableRawPointer?
    ) -> OSStatus {
        object == ObjectID.device ? noErr : kAudioHardwareBadObjectError
    }

    public func HasProperty(
        object: AudioObjectID, pid: pid_t, address a: UnsafePointer<AudioObjectPropertyAddress>
    ) -> Bool {
        property(object, a.pointee, 0, nil) != nil
            || device.HasProperty(object: object, pid: pid, address: a) != nil
    }

    public func IsPropertySettable(
        object: AudioObjectID, pid: pid_t, address a: UnsafePointer<AudioObjectPropertyAddress>,
        result: UnsafeMutablePointer<DarwinBoolean>
    ) -> OSStatus {
        if property(object, a.pointee, 0, nil) != nil {
            result.pointee = DarwinBoolean(isSettable(object, a.pointee))
            return noErr
        }
        switch device.HasProperty(object: object, pid: pid, address: a) {
        case .ReadOnly?:
            result.pointee = false
        case .Writable?:
            result.pointee = true
        case nil:
            return kAudioHardwareUnknownPropertyError
        }
        return noErr
    }

    public func GetPropertyDataSize(
        object: AudioObjectID, pid: pid_t, address a: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, size: UnsafeMutablePointer<UInt32>
    ) -> OSStatus {
        if let value: PropertyValue = property(object, a.pointee, qualifierSize, qualifier) {
            size.pointee = UInt32(value.byteCount)
            return noErr
        }
        size.pointee = 0
        guard device.HasProperty(object: object, pid: pid, address: a) != nil else {
            return kAudioHardwareUnknownPropertyError
        }
        guard qualifierSize == 0 || qualifier != nil else { return kAudioHardwareBadPropertySizeError }
        do {
            let count: Int = try device.GetPropertyDataSize(object: object, pid: pid, address: a,
                qualifier: UnsafeRawBufferPointer(start: qualifier, count: Int(qualifierSize)))
            guard let count: UInt32 = UInt32(exactly: count) else { return kAudioHardwareBadPropertySizeError }
            size.pointee = count
            return noErr
        } catch { return propertyErrorStatus(error) }
    }

    public func GetPropertyData(
        object: AudioObjectID, pid: pid_t, address a: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, capacity: UInt32,
        size: UnsafeMutablePointer<UInt32>, data: UnsafeMutableRawPointer
    ) -> OSStatus {
        if let value: PropertyValue = property(object, a.pointee, qualifierSize, qualifier) {
            return value.write(data, capacity, size)
        }
        size.pointee = 0
        guard device.HasProperty(object: object, pid: pid, address: a) != nil else {
            return kAudioHardwareUnknownPropertyError
        }
        guard qualifierSize == 0 || qualifier != nil else { return kAudioHardwareBadPropertySizeError }
        do {
            let count: Int = try device.GetPropertyData(object: object, pid: pid, address: a,
                qualifier: UnsafeRawBufferPointer(start: qualifier, count: Int(qualifierSize)),
                data: UnsafeMutableRawBufferPointer(start: data, count: Int(capacity)))
            guard let count: UInt32 = UInt32(exactly: count), count <= capacity else {
                return kAudioHardwareBadPropertySizeError
            }
            size.pointee = count
            return noErr
        } catch { return propertyErrorStatus(error) }
    }

    public func SetPropertyData(
        object: AudioObjectID, pid: pid_t, address a: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, size: UInt32, data: UnsafeRawPointer
    ) -> OSStatus {
        if property(object, a.pointee, 0, nil) != nil {
            return setProperty(object, a.pointee, size, data)
        }
        switch device.HasProperty(object: object, pid: pid, address: a) {
        case .Writable?: break
        case .ReadOnly?: return kAudioHardwareUnsupportedOperationError
        case nil: return kAudioHardwareUnknownPropertyError
        }
        guard qualifierSize == 0 || qualifier != nil else { return kAudioHardwareBadPropertySizeError }
        do {
            let count: Int = try device.SetPropertyData(object: object, pid: pid, address: a,
                qualifier: UnsafeRawBufferPointer(start: qualifier, count: Int(qualifierSize)),
                data: UnsafeRawBufferPointer(start: data, count: Int(size)))
            return count == Int(size) ? noErr : kAudioHardwareBadPropertySizeError
        } catch { return propertyErrorStatus(error) }
    }

    public func StartIO(object: AudioObjectID, client: UInt32) -> OSStatus {
        guard object == ObjectID.device else { return kAudioHardwareBadObjectError }
        let state: VirtualAudioDevice<Device> = self
        state.stateLock.withLock { control in
            if control.runningClients == 0 {
                state.resetClock(sampleRate: control.currentFormat.sampleRate, running: true)
            }
            control.runningClients += 1
        }
        return noErr
    }

    public func StopIO(object: AudioObjectID, client: UInt32) -> OSStatus {
        guard object == ObjectID.device else { return kAudioHardwareBadObjectError }
        let state: VirtualAudioDevice<Device> = self
        return state.stateLock.withLock { control in
            guard control.runningClients > 0 else { return kAudioHardwareIllegalOperationError }
            control.runningClients -= 1
            if control.runningClients == 0 {
                state.clockLock.withLock { $0.running = false }
            }
            return noErr
        }
    }

    public func GetZeroTimeStamp(
        object: AudioObjectID, client: UInt32, sample: UnsafeMutablePointer<Float64>,
        host: UnsafeMutablePointer<UInt64>, seed: UnsafeMutablePointer<UInt64>
    ) -> OSStatus {
        guard object == ObjectID.device else { return kAudioHardwareBadObjectError }
        let state: VirtualAudioDevice<Device> = self
        let timestamp: (Double, UInt64, UInt64) = state.clockLock.withLock { clock in
            let ticksPerFrame: Double = state.ticksPerSecond / clock.sampleRate
            let now: UInt64 = mach_absolute_time()
            let elapsed: UInt64 = now >= clock.anchorHost ? now - clock.anchorHost : 0
            let periods: Double =
                clock.running
                ? floor(Double(elapsed) / (ticksPerFrame * Double(state.timestampPeriod))) : 0
            let sampleTime: Double = periods * Double(state.timestampPeriod)
            let hostTime: UInt64 = clock.anchorHost + UInt64(sampleTime * ticksPerFrame)
            return (sampleTime, hostTime, clock.seed)
        }
        sample.pointee = timestamp.0
        host.pointee = timestamp.1
        seed.pointee = timestamp.2
        return noErr
    }

    public func WillDoIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32,
        willDo: UnsafeMutablePointer<DarwinBoolean>, inPlace: UnsafeMutablePointer<DarwinBoolean>
    ) -> OSStatus {
        guard object == ObjectID.device else { return kAudioHardwareBadObjectError }
        let supported: Bool =
            operation == AudioServerPlugInIOOperation.readInput.rawValue
            || operation == AudioServerPlugInIOOperation.writeMix.rawValue
        willDo.pointee = DarwinBoolean(supported)
        inPlace.pointee = true
        return noErr
    }

    public func BeginIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32, frames: UInt32,
        cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>
    ) -> OSStatus {
        object == ObjectID.device ? noErr : kAudioHardwareBadObjectError
    }

    public func DoIOOperation(
        object: AudioObjectID, stream: AudioObjectID, client: UInt32, operation: UInt32,
        frames: UInt32, cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>,
        buffer: UnsafeMutableRawPointer?, secondaryBuffer: UnsafeMutableRawPointer?
    ) -> OSStatus {
        guard object == ObjectID.device else { return kAudioHardwareBadObjectError }
        if operation == AudioServerPlugInIOOperation.writeMix.rawValue {
            return stream == ObjectID.output ? noErr : kAudioHardwareBadObjectError
        }
        guard operation == AudioServerPlugInIOOperation.readInput.rawValue else {
            return kAudioHardwareUnsupportedOperationError
        }
        guard stream == ObjectID.input else { return kAudioHardwareBadObjectError }
        guard frames <= maximumFramesToRender else { return kAudioUnitErr_TooManyFramesToProcess }
        guard let buffer: UnsafeMutableRawPointer = buffer else { return kAudioHardwareIllegalOperationError }
        let state: VirtualAudioDevice<Device> = self
        let render: VirtualAudioDeviceRenderState = state.renderState.reference.pointee
        var timestamp: AudioTimeStamp = cycle.pointee.mInputTime
        return render.block(&timestamp, frames, buffer)
    }

    public func EndIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32, frames: UInt32,
        cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>
    ) -> OSStatus {
        object == ObjectID.device ? noErr : kAudioHardwareBadObjectError
    }

}

extension AudioObjectPropertyAddress {
    @inlinable
    @_transparent
    init(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) {
        self.init(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain)
    }
}

@frozen
@usableFromInline
enum PropertyValue {
    case uint32(UInt32)
    case float64(Double)
    case text(CFString)
    case ids(Array<AudioObjectID>)
    case ranges(Array<AudioValueRange>)
    case format(AudioStreamBasicDescription)
    case formats(Array<AudioStreamRangedDescription>)

    @inlinable
    @_transparent
    var byteCount: Int {
        switch self {
        case PropertyValue.uint32: return MemoryLayout<UInt32>.size
        case PropertyValue.float64: return MemoryLayout<Double>.size
        case PropertyValue.text: return MemoryLayout<UnsafeRawPointer>.size
        case PropertyValue.ids(let a): return a.count * MemoryLayout<AudioObjectID>.stride
        case PropertyValue.ranges(let a): return a.count * MemoryLayout<AudioValueRange>.stride
        case PropertyValue.format: return MemoryLayout<AudioStreamBasicDescription>.size
        case PropertyValue.formats(let a): return a.count * MemoryLayout<AudioStreamRangedDescription>.stride
        }
    }

    @inlinable
    @_transparent
    func write(
        _ data: UnsafeMutableRawPointer, _ capacity: UInt32,
        _ size: UnsafeMutablePointer<UInt32>
    ) -> OSStatus {
        size.pointee = 0
        // HAL permits fetching prefixes of array properties.
        switch self {
        case PropertyValue.ids(let values): return writeArray(values, data, capacity, size)
        case PropertyValue.ranges(let values): return writeArray(values, data, capacity, size)
        case PropertyValue.formats(let values): return writeArray(values, data, capacity, size)
        default: break
        }
        guard Int(capacity) >= byteCount else { return kAudioHardwareBadPropertySizeError }
        switch self {
        case PropertyValue.uint32(let value): data.storeBytes(of: value, as: UInt32.self)
        case PropertyValue.float64(let value): data.storeBytes(of: value, as: Double.self)
        case PropertyValue.text(let value):
            // HAL's caller owns the returned CF reference.
            data.storeBytes(of: Unmanaged<CFString>.passRetained(value).toOpaque(), as: UnsafeMutableRawPointer.self)
        case PropertyValue.format(var value):
            withUnsafeBytes(of: &value) { data.copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
        default: break
        }
        size.pointee = UInt32(byteCount)
        return noErr
    }
}

@inlinable
@_transparent
func writeArray<T>(
    _ values: Array<T>, _ data: UnsafeMutableRawPointer,
    _ capacity: UInt32, _ size: UnsafeMutablePointer<UInt32>
) -> OSStatus {
    let bytes: Int = min(values.count, Int(capacity) / MemoryLayout<T>.stride) * MemoryLayout<T>.stride
    if bytes > 0 {
        values.withUnsafeBytes { data.copyMemory(from: $0.baseAddress!, byteCount: bytes) }
    }
    size.pointee = UInt32(bytes)
    return noErr
}

@inlinable
@_transparent
func streams(_ scope: AudioObjectPropertyScope) -> Array<AudioObjectID> {
    switch scope {
    case kAudioObjectPropertyScopeGlobal: return [ObjectID.input, ObjectID.output]
    case kAudioObjectPropertyScopeInput: return [ObjectID.input]
    case kAudioObjectPropertyScopeOutput: return [ObjectID.output]
    default: return []
    }
}

@inlinable
@_transparent
func isSettable(_ object: AudioObjectID, _ a: AudioObjectPropertyAddress) -> Bool {
    if object == ObjectID.device { return a.mSelector == kAudioDevicePropertyNominalSampleRate }
    return (object == ObjectID.input || object == ObjectID.output)
        && [
            kAudioStreamPropertyIsActive, kAudioStreamPropertyVirtualFormat,
            kAudioStreamPropertyPhysicalFormat,
        ].contains(a.mSelector)
}

extension VirtualAudioDevice {
    @inlinable
    @_transparent
    func property(
        _ object: AudioObjectID, _ a: AudioObjectPropertyAddress,
        _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?
    ) -> PropertyValue? {
        guard [ObjectID.plugin, ObjectID.device, ObjectID.input, ObjectID.output].contains(object),
            a.mElement == kAudioObjectPropertyElementMain,
            a.mScope == kAudioObjectPropertyScopeGlobal
                || (object == ObjectID.device
                    && (a.mScope == kAudioObjectPropertyScopeInput || a.mScope == kAudioObjectPropertyScopeOutput))
        else { return nil }

        switch a.mSelector {
        case kAudioObjectPropertyBaseClass: return PropertyValue.uint32(kAudioObjectClassID)
        case kAudioObjectPropertyClass:
            return PropertyValue.uint32(
                object == ObjectID.plugin
                    ? kAudioPlugInClassID
                    : object == ObjectID.device ? kAudioDeviceClassID : kAudioStreamClassID)
        case kAudioObjectPropertyOwner:
            return PropertyValue.uint32(
                object == ObjectID.plugin
                    ? kAudioObjectUnknown
                    : object == ObjectID.device ? ObjectID.plugin : ObjectID.device)
        case kAudioObjectPropertyName:
            return PropertyValue.text(
                (object == ObjectID.plugin
                    ? name + " Plug-in"
                    : object == ObjectID.device
                        ? name
                        : object == ObjectID.input
                            ? inputStreamName : outputStreamName)
                    as CFString)
        case kAudioObjectPropertyManufacturer: return PropertyValue.text(manufacturer as CFString)
        case kAudioObjectPropertyOwnedObjects:
            return PropertyValue.ids(
                object == ObjectID.plugin
                    ? [ObjectID.device]
                    : object == ObjectID.device ? streams(a.mScope) : [])
        default: break
        }

        if object == ObjectID.plugin {
            switch a.mSelector {
            case kAudioPlugInPropertyBundleID: return PropertyValue.text(bundleIdentifier as CFString)
            case kAudioPlugInPropertyDeviceList: return PropertyValue.ids([ObjectID.device])
            case kAudioPlugInPropertyTranslateUIDToDevice:
                guard qualifierSize == MemoryLayout<CFString?>.size, let qualifier: UnsafeRawPointer = qualifier,
                    let uid: CFString = qualifier.load(as: CFString?.self)
                else { return PropertyValue.uint32(kAudioObjectUnknown) }
                return PropertyValue.uint32(
                    CFEqual(uid, self.uid as CFString)
                        ? ObjectID.device : kAudioObjectUnknown)
            case kAudioPlugInPropertyBoxList: return PropertyValue.ids([])
            case kAudioPlugInPropertyResourceBundle: return PropertyValue.text("" as CFString)
            default: return nil
            }
        }

        if object == ObjectID.device {
            return switch a.mSelector {
            case kAudioDevicePropertyDeviceUID:
                PropertyValue.text(uid as CFString)
            case kAudioDevicePropertyModelUID:
                PropertyValue.text(modelUID as CFString)
            case kAudioDevicePropertyTransportType:
                PropertyValue.uint32(kAudioDeviceTransportTypeVirtual)
            case kAudioDevicePropertyRelatedDevices:
                PropertyValue.ids([ObjectID.device])
            case kAudioDevicePropertyClockDomain, kAudioDevicePropertyLatency,
                kAudioDevicePropertySafetyOffset, kAudioDevicePropertyIsHidden,
                kAudioDevicePropertyDeviceCanBeDefaultSystemDevice:
                PropertyValue.uint32(0)
            case kAudioDevicePropertyDeviceIsAlive, kAudioDevicePropertyDeviceCanBeDefaultDevice:
                PropertyValue.uint32(1)
            case kAudioDevicePropertyDeviceIsRunning:
                PropertyValue.uint32(0 < stateLock.withLock(\.runningClients) ? 1 : 0)
            case kAudioDevicePropertyStreams:
                PropertyValue.ids(streams(a.mScope))
            case kAudioObjectPropertyControlList:
                PropertyValue.ids([])
            case kAudioDevicePropertyNominalSampleRate:
                PropertyValue.float64(stateLock.withLock(\.currentFormat.sampleRate))
            case kAudioDevicePropertyAvailableNominalSampleRates:
                PropertyValue.ranges(Array<Double>(Set<Double>(formats.map(\.sampleRate))).sorted().map {
                    AudioValueRange(mMinimum: $0, mMaximum: $0)
                })
            case kAudioDevicePropertyPreferredChannelsForStereo:
                PropertyValue.ids([1, min(2, formats[0].channelCount)])
            case kAudioDevicePropertyZeroTimeStampPeriod:
                PropertyValue.uint32(timestampPeriod)
            default:
                nil
            }
        }

        return switch a.mSelector {
        case kAudioStreamPropertyIsActive:
            PropertyValue.uint32(
                object == ObjectID.input
                    ? stateLock.withLock(\.inputActive)
                    : stateLock.withLock(\.outputActive))
        case kAudioStreamPropertyDirection:
            PropertyValue.uint32(object == ObjectID.input ? 1 : 0)
        case kAudioStreamPropertyTerminalType:
            PropertyValue.uint32(kAudioStreamTerminalTypeLine)
        case kAudioStreamPropertyStartingChannel:
            PropertyValue.uint32(1)
        case kAudioStreamPropertyLatency:
            PropertyValue.uint32(0)
        case kAudioStreamPropertyVirtualFormat, kAudioStreamPropertyPhysicalFormat:
            PropertyValue.format(stateLock.withLock { halStreamDescription($0.currentFormat) })
        case kAudioStreamPropertyAvailableVirtualFormats, kAudioStreamPropertyAvailablePhysicalFormats:
            PropertyValue.formats(
                formats.reduce(into: Array<AudioStreamRangedDescription>()) { result, format in
                    let description: AudioStreamBasicDescription = halStreamDescription(format)
                    if !result.contains(where: { sameStreamDescription($0.mFormat, description) }) {
                        result.append(AudioStreamRangedDescription(mFormat: description,
                            mSampleRateRange: AudioValueRange(mMinimum: format.sampleRate, mMaximum: format.sampleRate)))
                    }
                })
        default:
            nil
        }
    }

    @inlinable
    @_transparent
    func setProperty(
        _ object: AudioObjectID, _ a: AudioObjectPropertyAddress,
        _ size: UInt32, _ data: UnsafeRawPointer?
    ) -> OSStatus {
        guard property(object, a, 0, nil) != nil else { return kAudioHardwareUnknownPropertyError }
        guard isSettable(object, a) else { return kAudioHardwareUnsupportedOperationError }
        guard let data: UnsafeRawPointer = data else { return kAudioHardwareIllegalOperationError }

        if a.mSelector == kAudioStreamPropertyIsActive {
            guard size == MemoryLayout<UInt32>.size else { return kAudioHardwareBadPropertySizeError }
            let value: UInt32 = data.load(as: UInt32.self) == 0 ? 0 : 1
            stateLock.withLock { control in
                if object == ObjectID.input { control.inputActive = value } else { control.outputActive = value }
            }
            notify(object, [a])
            return noErr
        }

        let available: Array<AVAudioFormat> = formats
        let (current, hasHost): (AVAudioFormat, Bool) = stateLock.withLockUnchecked {
            ($0.currentFormat, $0.host != nil)
        }
        let formatIndex: Int?
        if a.mSelector == kAudioDevicePropertyNominalSampleRate {
            guard size == MemoryLayout<Double>.size else { return kAudioHardwareBadPropertySizeError }
            let rate: Double = data.load(as: Double.self)
            // Keep both the sample representation and AU layout when changing rate.
            formatIndex = available.firstIndex {
                $0.sampleRate == rate && $0.commonFormat == current.commonFormat
                    && $0.isInterleaved == current.isInterleaved
            } ?? available.firstIndex {
                $0.sampleRate == rate && $0.commonFormat == current.commonFormat
            } ?? available.firstIndex { $0.sampleRate == rate }
        } else {
            guard size == MemoryLayout<AudioStreamBasicDescription>.size else {
                return kAudioHardwareBadPropertySizeError
            }
            let candidate: AudioStreamBasicDescription = data.load(as: AudioStreamBasicDescription.self)
            formatIndex = available.firstIndex {
                $0.isInterleaved == current.isInterleaved && sameStreamDescription(candidate, halStreamDescription($0))
            } ?? available.firstIndex { sameStreamDescription(candidate, halStreamDescription($0)) }
        }
        guard let formatIndex: Int = formatIndex else { return kAudioDeviceUnsupportedFormatError }
        guard !available[formatIndex].isEqual(current) else { return noErr }
        guard hasHost else { return kAudioHardwareIllegalOperationError }
        // HAL performs stop/configure/restart. Never mutate the format in a property setter.
        DispatchQueue.global().async { [self] in
            guard let host: AudioServerPlugInHostRef = stateLock.withLockUnchecked(\.host) else { return }
            _ = host.pointee.RequestDeviceConfigurationChange(host, ObjectID.device, UInt64(formatIndex) + 1, nil)
        }
        return noErr
    }
}
