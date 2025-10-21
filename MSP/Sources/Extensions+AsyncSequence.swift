//
//  AsyncSequence+.swift
//  MUTE
//
//  Created by Kota on 5/15/R7.
//
@preconcurrency import Combine
extension AsyncSequence where Self: Sendable {
	@usableFromInline
	var publisher: some Publisher<Element, Failure> & Sendable {
		let thru = PassthroughSubject<Element, Failure>()
		return thru.handleEvents(receiveCancel: Task { [unowned thru] in
			do throws (Failure) {
				for try await element in self {
					thru.send(element)
				}
				thru.send(completion: .finished)
			} catch {
				thru.send(completion: .failure(error))
			}
		}.cancel)
	}
}
