import CoreAudio
import CoreAudio.AudioServerPlugIn
import CoreFoundation
import Darwin
import Synchronization
import Auxiliary

// CFUUID instances are immutable and shared read-only.
@usableFromInline
nonisolated(unsafe) let pluginType: CFUUID = CFUUIDCreateFromString(
    nil, "443ABAB8-E7B3-491A-B985-BEB9187030DB" as CFString)!
@usableFromInline
nonisolated(unsafe) let driverType: CFUUID = CFUUIDCreateFromString(
    nil, "EEA5773D-CC43-49F1-8E00-8F96E7D23B17" as CFString)!
@usableFromInline
nonisolated(unsafe) let unknownType: CFUUID = CFUUIDCreateFromString(
    nil, "00000000-0000-0000-C000-000000000046" as CFString)!

public protocol AudioServerPlugInDriverInterfaceProtocol: Sendable {
    func Initialize(host: AudioServerPlugInHostRef) -> OSStatus
    func CreateDevice(description: CFDictionary, client: UnsafePointer<AudioServerPlugInClientInfo>, result: UnsafeMutablePointer<AudioObjectID>) -> OSStatus
    func DestroyDevice(object: AudioObjectID) -> OSStatus
    func AddDeviceClient(object: AudioObjectID, client: UnsafePointer<AudioServerPlugInClientInfo>) -> OSStatus
    func RemoveDeviceClient(
        object: AudioObjectID, client: UnsafePointer<AudioServerPlugInClientInfo>
    ) -> OSStatus
    func PerformDeviceConfigurationChange(
        object: AudioObjectID, action: UInt64, info: UnsafeMutableRawPointer?
    ) -> OSStatus
    func AbortDeviceConfigurationChange(
        object: AudioObjectID, action: UInt64, info: UnsafeMutableRawPointer?
    ) -> OSStatus
    func HasProperty(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>
    ) -> Bool
    func IsPropertySettable(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        result: UnsafeMutablePointer<DarwinBoolean>
    ) -> OSStatus
    func GetPropertyDataSize(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, size: UnsafeMutablePointer<UInt32>
    ) -> OSStatus
    func GetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, capacity: UInt32,
        size: UnsafeMutablePointer<UInt32>, data: UnsafeMutableRawPointer
    ) -> OSStatus
    func SetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, size: UInt32, data: UnsafeRawPointer
    ) -> OSStatus
    func StartIO(object: AudioObjectID, client: UInt32) -> OSStatus
    func StopIO(object: AudioObjectID, client: UInt32) -> OSStatus
    func GetZeroTimeStamp(
        object: AudioObjectID, client: UInt32, sample: UnsafeMutablePointer<Float64>,
        host: UnsafeMutablePointer<UInt64>, seed: UnsafeMutablePointer<UInt64>
    ) -> OSStatus
    func WillDoIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32,
        willDo: UnsafeMutablePointer<DarwinBoolean>, inPlace: UnsafeMutablePointer<DarwinBoolean>
    ) -> OSStatus
    func BeginIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32, frames: UInt32,
        cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>
    ) -> OSStatus
    func DoIOOperation(
        object: AudioObjectID, stream: AudioObjectID, client: UInt32, operation: UInt32,
        frames: UInt32, cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>,
        buffer: UnsafeMutableRawPointer?, secondaryBuffer: UnsafeMutableRawPointer?
    ) -> OSStatus
    func EndIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32, frames: UInt32,
        cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>
    ) -> OSStatus
}

public final class AudioServerPlugInDriverInterfaceOwner: Sendable {
    @usableFromInline typealias Context = (UnsafePointer<AudioServerPlugInDriverInterface>, UnsafeMutableRawPointer)
    @usableFromInline nonisolated(unsafe) let storage: UnsafeMutablePointer<Context>
    @usableFromInline let counter: Atomic<ULONG> = Atomic<ULONG>(0)
    @usableFromInline let delegate: any AudioServerPlugInDriverInterfaceProtocol

    @inlinable
    public init(driver: some AudioServerPlugInDriverInterfaceProtocol) {
        delegate = driver
        storage = UnsafeMutablePointer<Context>.allocate(capacity: 1)
        storage.initialize(to: (
            UnsafePointer<AudioServerPlugInDriverInterface>(Self.vtable.reference),
            Unmanaged<AudioServerPlugInDriverInterfaceOwner>.passUnretained(self).toOpaque()
        ))
    }

    @inlinable
    deinit {
        storage.deallocate()
    }

    /// Returns the same HAL interface with an additional owned COM reference.
    /// The recipient must balance each call with COM Release, or transfer that obligation to HAL.
    @inlinable
    public func copyRetainedReference() -> AudioServerPlugInDriverRef {
        withExtendedLifetime(self) {
            let reference: AudioServerPlugInDriverRef = UnsafeMutableRawPointer(storage).assumingMemoryBound(
                to: UnsafeMutablePointer<AudioServerPlugInDriverInterface>?.self)
            _ = Self.vtable.reference.pointee.AddRef(UnsafeMutableRawPointer(reference))
            return reference
        }
    }

    @usableFromInline
    static let vtable: Autorelease.Object<AudioServerPlugInDriverInterface> = {
        let object: Autorelease.Object<AudioServerPlugInDriverInterface> = Autorelease.Object<AudioServerPlugInDriverInterface>(object: UnsafeMutablePointer<AudioServerPlugInDriverInterface>.allocate(capacity: 1)) {
            $0.deinitialize(count: 1)
            $0.deallocate()
        }
        object.reference.initialize(to: AudioServerPlugInDriverInterface(
            _reserved: nil,
            QueryInterface: {
                guard let res: UnsafeMutablePointer<LPVOID?> = $2 else { return HRESULT(bitPattern: 0x8000_4003) }
                res.pointee = nil
                guard let raw: UnsafeMutableRawPointer = $0, let uuid: CFUUID = CFUUIDCreateFromUUIDBytes(nil, $1) else {
                    return HRESULT(bitPattern: 0x8000_4003)
                }
                guard CFEqual(uuid, driverType) || CFEqual(uuid, unknownType) else {
                    return HRESULT(bitPattern: 0x8000_4002)
                }
                let owner: Unmanaged<AudioServerPlugInDriverInterfaceOwner> = Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    raw.assumingMemoryBound(to: Context.self).pointee.1
                )
                owner.retain().takeUnretainedValue().counter.wrappingAdd(1, ordering: AtomicUpdateOrdering.acquiringAndReleasing)
                res.pointee = raw
                return 0
            },
            AddRef: {
                guard let raw: UnsafeMutableRawPointer = $0 else { return 0 }
                let owner: Unmanaged<AudioServerPlugInDriverInterfaceOwner> = Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    raw.assumingMemoryBound(to: Context.self).pointee.1
                )
                return owner.retain().takeUnretainedValue().counter.wrappingAdd(
                    1, ordering: AtomicUpdateOrdering.acquiringAndReleasing
                ).newValue
            },
            Release: {
                guard let raw: UnsafeMutableRawPointer = $0 else { return 0 }
                let owner: Unmanaged<AudioServerPlugInDriverInterfaceOwner> = Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    raw.assumingMemoryBound(to: Context.self).pointee.1
                )
                defer {
                    owner.release()
                }
                let change: (oldValue: ULONG, newValue: ULONG) = owner.takeUnretainedValue().counter.wrappingSubtract(
                    1, ordering: AtomicUpdateOrdering.acquiringAndReleasing
                )
                precondition(change.oldValue > 0, "Unbalanced COM Release")
                return change.newValue
            },
            Initialize: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().Initialize(host: $1)
            },
            CreateDevice: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().CreateDevice(description: $1, client: $2, result: $3)
            },
            DestroyDevice: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().DestroyDevice(object: $1)
            },
            AddDeviceClient: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().AddDeviceClient(object: $1, client: $2)
            },
            RemoveDeviceClient: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().RemoveDeviceClient(object: $1, client: $2)
            },
            PerformDeviceConfigurationChange: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().PerformDeviceConfigurationChange(object: $1, action: $2, info: $3)
            },
            AbortDeviceConfigurationChange: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().AbortDeviceConfigurationChange(object: $1, action: $2, info: $3)
            },
            HasProperty: {
                DarwinBoolean(Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().HasProperty(object: $1, pid: $2, address: $3))
            },
            IsPropertySettable: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().IsPropertySettable(object: $1, pid: $2, address: $3, result: $4)
            },
            GetPropertyDataSize: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().GetPropertyDataSize(object: $1, pid: $2, address: $3, qualifierSize: $4, qualifier: $5, size: $6)
            },
            GetPropertyData: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().GetPropertyData(object: $1, pid: $2, address: $3, qualifierSize: $4, qualifier: $5, capacity: $6, size: $7, data: $8)
            },
            SetPropertyData: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().SetPropertyData(object: $1, pid: $2, address: $3, qualifierSize: $4, qualifier: $5, size: $6, data: $7)
            },
            StartIO: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().StartIO(object: $1, client: $2)
            },
            StopIO: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().StopIO(object: $1, client: $2)
            },
            GetZeroTimeStamp: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().GetZeroTimeStamp(object: $1, client: $2, sample: $3, host: $4, seed: $5)
            },
            WillDoIOOperation: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().WillDoIOOperation(object: $1, client: $2, operation: $3, willDo: $4, inPlace: $5)
            },
            BeginIOOperation: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().BeginIOOperation(object: $1, client: $2, operation: $3, frames: $4, cycle: $5)
            },
            DoIOOperation: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().DoIOOperation(object: $1, stream: $2, client: $3, operation: $4, frames: $5, cycle: $6, buffer: $7, secondaryBuffer: $8)
            },
            EndIOOperation: {
                Unmanaged<AudioServerPlugInDriverInterfaceOwner>.fromOpaque(
                    $0.withMemoryRebound(to: Context.self, capacity: 1, \.pointee.1)
                ).takeUnretainedValue().EndIOOperation(object: $1, client: $2, operation: $3, frames: $4, cycle: $5)
            }
        ))
        return object
    }()
}
extension AudioServerPlugInDriverInterfaceOwner: AudioServerPlugInDriverInterfaceProtocol {
    @inlinable
    @_transparent
    public func Initialize(host: AudioServerPlugInHostRef) -> OSStatus {
        delegate.Initialize(host: host)
    }

    @inlinable
    @_transparent
    public func CreateDevice(description: CFDictionary, client: UnsafePointer<AudioServerPlugInClientInfo>, result: UnsafeMutablePointer<AudioObjectID>) -> OSStatus {
        delegate.CreateDevice(description: description, client: client, result: result)
    }

    @inlinable
    @_transparent
    public func DestroyDevice(object: AudioObjectID) -> OSStatus {
        delegate.DestroyDevice(object: object)
    }

    @inlinable
    @_transparent
    public func AddDeviceClient(object: AudioObjectID, client: UnsafePointer<AudioServerPlugInClientInfo>) -> OSStatus {
        delegate.AddDeviceClient(object: object, client: client)
    }

    @inlinable
    @_transparent
    public func RemoveDeviceClient(
        object: AudioObjectID, client: UnsafePointer<AudioServerPlugInClientInfo>
    ) -> OSStatus {
        delegate.RemoveDeviceClient(object: object, client: client)
    }

    @inlinable
    @_transparent
    public func PerformDeviceConfigurationChange(
        object: AudioObjectID, action: UInt64, info: UnsafeMutableRawPointer?
    ) -> OSStatus {
        delegate.PerformDeviceConfigurationChange(object: object, action: action, info: info)
    }

    @inlinable
    @_transparent
    public func AbortDeviceConfigurationChange(
        object: AudioObjectID, action: UInt64, info: UnsafeMutableRawPointer?
    ) -> OSStatus {
        delegate.AbortDeviceConfigurationChange(object: object, action: action, info: info)
    }

    @inlinable
    @_transparent
    public func HasProperty(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>
    ) -> Bool {
        delegate.HasProperty(object: object, pid: pid, address: address)
    }

    @inlinable
    @_transparent
    public func IsPropertySettable(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        result: UnsafeMutablePointer<DarwinBoolean>
    ) -> OSStatus {
        delegate.IsPropertySettable(object: object, pid: pid, address: address, result: result)
    }

    @inlinable
    @_transparent
    public func GetPropertyDataSize(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, size: UnsafeMutablePointer<UInt32>
    ) -> OSStatus {
        delegate.GetPropertyDataSize(object: object, pid: pid, address: address, qualifierSize: qualifierSize, qualifier: qualifier, size: size)
    }

    @inlinable
    @_transparent
    public func GetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, capacity: UInt32,
        size: UnsafeMutablePointer<UInt32>, data: UnsafeMutableRawPointer
    ) -> OSStatus {
        delegate.GetPropertyData(object: object, pid: pid, address: address, qualifierSize: qualifierSize, qualifier: qualifier, capacity: capacity, size: size, data: data)
    }

    @inlinable
    @_transparent
    public func SetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifierSize: UInt32, qualifier: UnsafeRawPointer?, size: UInt32, data: UnsafeRawPointer
    ) -> OSStatus {
        delegate.SetPropertyData(object: object, pid: pid, address: address, qualifierSize: qualifierSize, qualifier: qualifier, size: size, data: data)
    }

    @inlinable
    @_transparent
    public func StartIO(object: AudioObjectID, client: UInt32) -> OSStatus {
        delegate.StartIO(object: object, client: client)
    }

    @inlinable
    @_transparent
    public func StopIO(object: AudioObjectID, client: UInt32) -> OSStatus {
        delegate.StopIO(object: object, client: client)
    }

    @inlinable
    @_transparent
    public func GetZeroTimeStamp(
        object: AudioObjectID, client: UInt32, sample: UnsafeMutablePointer<Float64>,
        host: UnsafeMutablePointer<UInt64>, seed: UnsafeMutablePointer<UInt64>
    ) -> OSStatus {
        delegate.GetZeroTimeStamp(object: object, client: client, sample: sample, host: host, seed: seed)
    }

    @inlinable
    @_transparent
    public func WillDoIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32,
        willDo: UnsafeMutablePointer<DarwinBoolean>, inPlace: UnsafeMutablePointer<DarwinBoolean>
    ) -> OSStatus {
        delegate.WillDoIOOperation(object: object, client: client, operation: operation, willDo: willDo, inPlace: inPlace)
    }

    @inlinable
    @_transparent
    public func BeginIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32, frames: UInt32,
        cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>
    ) -> OSStatus {
        delegate.BeginIOOperation(object: object, client: client, operation: operation, frames: frames, cycle: cycle)
    }

    @inlinable
    @_transparent
    public func DoIOOperation(
        object: AudioObjectID, stream: AudioObjectID, client: UInt32, operation: UInt32,
        frames: UInt32, cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>,
        buffer: UnsafeMutableRawPointer?, secondaryBuffer: UnsafeMutableRawPointer?
    ) -> OSStatus {
        delegate.DoIOOperation(object: object, stream: stream, client: client, operation: operation, frames: frames, cycle: cycle, buffer: buffer, secondaryBuffer: secondaryBuffer)
    }

    @inlinable
    @_transparent
    public func EndIOOperation(
        object: AudioObjectID, client: UInt32, operation: UInt32, frames: UInt32,
        cycle: UnsafePointer<AudioServerPlugInIOCycleInfo>
    ) -> OSStatus {
        delegate.EndIOOperation(object: object, client: client, operation: operation, frames: frames, cycle: cycle)
    }
}
