//
//  PassthroughSubjectTests.swift
//
//
//  Created by Danny Pang on 11.19.2022.
//

import XCTest

#if swift(>=5.7)

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
@available(macOS 10.15, iOS 13.0, *)
private typealias Published = Combine.Published
@available(macOS 10.15, iOS 13.0, *)
private typealias ObservableObject = Combine.ObservableObject
#else
import OpenCombine
private typealias Published = OpenCombine.Published
private typealias ObservableObject = OpenCombine.ObservableObject
#endif

@available(macOS 10.15, iOS 13.0, *)
final class PrimaryAssociatedTypeTests: XCTestCase {

    func testCombinePrimaryAssociatedTypes() {
        let exp1 = expectation(description: "PrimaryAssociatedTypeTests")

        let just: some Publisher<Int, Never> = Just(0)
        let cs1: some ConnectablePublisher<Int, Never> = just.makeConnectable()
        let subject: some Subject<Int, Never> = PassthroughSubject()
        let p2: some Publisher<Int, Never> = subject.eraseToAnyPublisher()
        let sink: some Subscriber<Int, Never> = Subscribers.Sink(
            receiveCompletion: { _ in
                exp1.fulfill()
            }, receiveValue: { value in 
                print(value) 
            }
        )

        p2.subscribe(sink)
        subject.send(1)
        subject.send(completion: .finished)
        wait(for: [exp1], timeout: 0.1)
	}
}
#endif