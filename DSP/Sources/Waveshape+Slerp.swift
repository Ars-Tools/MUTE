//
//  Waveshape+Slerp.swift
//  MUTE
//
//  Created by Kota on 9/2/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Just
import typealias Numerics.Quaternion256
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import func NSP.slerp_shortest
import func NSP.slerp_longest
@usableFromInline
enum Slerp {
	@usableFromInline
	struct Kr<S: Publisher<Quaternion256, Never> & Sendable, T: Publisher<Quaternion256, Never> & Sendable> {
		@usableFromInline let s: S
		@usableFromInline let t: T
		@usableFromInline let phasor: Stream
	}
}
import Darwin
extension Slerp.Kr: Stream {
	@inlinable
	var count: Int {
		4
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try phasor(interval: interval, capacity: capacity, instance: &instance)
		let q₀ = Mutex<Quaternion256>(0)
		let q₁ = Mutex<Quaternion256>(0)
        let cancel = (
            s.sink { s in
                q₀.withLock {
                    $0 = s
                }
            },
            t.sink { t in
                q₁.withLock {
                    $0 = t
                }
            }
        )
        return { [cancel] in
			kernel($0, $1, $2, $3)
            slerp_longest(q₀.withLock(\.self), q₁.withLock(\.self),
						   $2,
						   $2, $3,
						   $1)
		}
	}
}
public func slerp(phasor: Stream, s: some Publisher<Quaternion256, Never> & Sendable, t: some Publisher<Quaternion256, Never> & Sendable) -> some Stream {
	Slerp.Kr(s: s, t: t, phasor: phasor)
}
public func slerp(phasor: Stream, s: Quaternion256, t: Quaternion256) -> some Stream {
    Slerp.Kr(s: Just(s), t: Just(t), phasor: phasor)
}
