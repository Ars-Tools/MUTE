//
//  Extension+AsyncSequence.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import class Combine.PassthroughSubject
extension AsyncSequence where Self: Sendable {
	@usableFromInline
	var publisher: some Publisher<Element, Failure> & Sendable {
		let thru = PassthroughSubject<Element, Failure>()
		let task = Task { [unowned thru] in
			do throws (Failure) {
				for try await element in self {
					thru.send(element)
				}
				thru.send(completion: .finished)
			} catch {
				thru.send(completion: .failure(error))
			}
		}
		return thru.handleEvents(receiveCompletion: .some({ [task] completion in
			task.cancel()
		}), receiveCancel: .some(task.cancel))
	}
}
