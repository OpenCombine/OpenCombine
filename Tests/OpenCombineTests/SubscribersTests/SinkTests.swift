//
//  SinkTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class SinkTests: XCTestCase {

    private typealias Sut = Subscribers.Sink<Int, Never>

    func testDescription() {
        let sink = Sut(receiveCompletion: { _ in }, receiveValue: { _ in })

        XCTAssertEqual(sink.description, "Sink")
        XCTAssertEqual(sink.playgroundDescription as? String, "Sink")
    }

    func testReflection() {
        let sink = Sut(receiveCompletion: { _ in }, receiveValue: { _ in })
        XCTAssert(sink.customMirror.children.isEmpty)
    }

    func testSubscription() {

        let sink = Sut(receiveCompletion: { _ in }, receiveValue: { _ in })

        let subscription1 = CustomSubscription()
        sink.receive(subscription: subscription1)
        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])
        XCTAssertFalse(subscription1.cancelled)

        let subscription2 = CustomSubscription()
        sink.receive(subscription: subscription2)
        XCTAssertFalse(subscription1.cancelled)
        XCTAssertTrue(subscription2.cancelled)

        sink.receive(subscription: subscription1)
        XCTAssertTrue(subscription1.cancelled)

        subscription1.cancelled = false
        sink.receive(completion: .finished)
        XCTAssertFalse(subscription1.cancelled)

        let subscription3 = CustomSubscription()
        sink.receive(subscription: subscription3)
        XCTAssertEqual(subscription3.history, [.cancelled])
        XCTAssertTrue(subscription3.cancelled)
    }

    func testReceiveValue() {

        var value = 0
        var completion: Subscribers.Completion<Never>?

        let sink = Sut(receiveCompletion: { completion = $0 },
                       receiveValue: { value = $0 })

        let publisher = PassthroughSubject<Int, Never>()

        XCTAssertEqual(sink.receive(12), .none)
        XCTAssertEqual(value, 12)
        XCTAssertNil(completion)

        publisher.subscribe(sink)
        publisher.send(42)
        XCTAssertEqual(value, 42)
        XCTAssertNil(completion)

        publisher.send(completion: .finished)
        XCTAssertEqual(value, 42)
        XCTAssertNotNil(completion)

        XCTAssertEqual(sink.receive(100), .none)
        XCTAssertEqual(value, 100)

        publisher.subscribe(sink)
        publisher.send(1000000)
        XCTAssertEqual(value, 100)

        sink.cancel()
        publisher.send(-1)
        XCTAssertEqual(value, 100)
    }

    func testReceiveValueWithoutSubscription() {
        var valueCounter = 0
        var completionCounter = 0
        let sink = Subscribers.Sink<Void, TestingError>(
            receiveCompletion: { _ in completionCounter += 1 },
            receiveValue: { valueCounter += 1 }
        )

        XCTAssertEqual(sink.receive(), .none)
        XCTAssertEqual(valueCounter, 1)
        XCTAssertEqual(completionCounter, 0)

        sink.receive(completion: .finished)

        XCTAssertEqual(valueCounter, 1)
        XCTAssertEqual(completionCounter, 1)

        XCTAssertEqual(sink.receive(), .none)
        sink.receive(completion: .finished)
        sink.receive(completion: .failure(.oops))

        XCTAssertEqual(valueCounter, 2)
        XCTAssertEqual(completionCounter, 3)

        sink.cancel()

        XCTAssertEqual(completionCounter, 3)
    }

    func testPublisherOperator() {
        var value = 0
        let publisher = PassthroughSubject<Int, Never>()

        let sink = publisher.sink(receiveValue: { value = $0 })
        XCTAssertEqual(value, 0)

        publisher.send(42)
        XCTAssertEqual(value, 42)

        sink.cancel()
        publisher.send(1)
        XCTAssertEqual(value, 42)

        do {
            _ = publisher.sink(receiveValue: { value = $0 })
        }

        publisher.send(100)
        XCTAssertEqual(value, 42)
    }
}
