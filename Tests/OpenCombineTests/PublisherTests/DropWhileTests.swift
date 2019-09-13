//
//  DropWhileTests.swift
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
final class DropWhileTests: XCTestCase {

    func testDropWhile() {

        var counter = 0 // How many times the predicate is called?

        let publisher = PassthroughSubject<Int, TestingError>()
        let drop = publisher.drop(while: { counter += 1; return $0.isMultiple(of: 2) })
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        publisher.send(1)
        drop.subscribe(tracking)
        publisher.send(2)
        publisher.send(4)
        publisher.send(6)
        publisher.send(7)
        publisher.send(8)
        publisher.send(9)
        publisher.send(completion: .finished)
        publisher.send(10)

        XCTAssertEqual(tracking.history, [.subscription("DropWhile"),
                                          .value(7),
                                          .value(8),
                                          .value(9),
                                          .completion(.finished)])

        XCTAssertEqual(counter, 4)
    }

    func testTryDropWhileFailureBecauseOfThrow() {

        var counter = 0 // How many times the predicate is called?

        let publisher = PassthroughSubject<Int, Error>()
        let drop = publisher.tryDrop {
            counter += 1
            if $0 == 100 {
                throw "too much" as TestingError
            }
            return $0.isMultiple(of: 2)
        }
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.send(1)
        drop.subscribe(tracking)
        publisher.send(2)
        publisher.send(4)
        publisher.send(100)
        publisher.send(9)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure("too much" as TestingError))])

        XCTAssertEqual(counter, 3)
    }

    func testTryDropWhileFailureOnCompletion() {

        let publisher = PassthroughSubject<Int, Error>()
        let drop = publisher.tryDrop { $0.isMultiple(of: 2) }

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        drop.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        publisher.send(2)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure(TestingError.oops))])
    }

    func testTryDropWhileSuccess() {

        let publisher = PassthroughSubject<Int, Error>()
        let drop = publisher.tryDrop { $0.isMultiple(of: 2) }

        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.max(2)) }
        )

        publisher.send(1)
        drop.subscribe(tracking)
        publisher.send(0)
        publisher.send(2)
        publisher.send(3)
        publisher.send(4)
        publisher.send(5)
        publisher.send(completion: .finished)
        publisher.send(8)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryDropWhile"),
                        .value(3),
                        .value(4),
                        .completion(.finished)])
    }

    func testDemand() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.drop(while: { $0.isMultiple(of: 2) })
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(42))
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(4) }
        )

        drop.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        XCTAssertEqual(publisher.send(0), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        XCTAssertEqual(publisher.send(2), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        downstreamSubscription?.request(.max(95))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5))])

        XCTAssertEqual(publisher.send(3), .max(4))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5))])

        downstreamSubscription?.request(.max(121))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .requested(.max(121))])

        XCTAssertEqual(publisher.send(7), .max(4))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .requested(.max(121))])

        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .requested(.max(121)),
                                              .cancelled])

        downstreamSubscription?.request(.max(50))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .requested(.max(121)),
                                              .cancelled])

        XCTAssertEqual(publisher.send(8), .none)
    }

    func testTryDropWhileCancelsUpstreamOnThrow() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.tryDrop(while: { _ in throw "too much" as TestingError })
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in .max(42) }
        )

        drop.subscribe(tracking)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(publisher.send(100), .none)
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
        publisher.send(completion: .finished)
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure("too much" as TestingError))])
        XCTAssertEqual(publisher.send(12), .none)
        XCTAssertEqual(tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure("too much" as TestingError))])
    }

    func testDropWhileCompletion() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.drop(while: { _ in true })
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )

        drop.subscribe(tracking)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        publisher.send(completion: .finished)
        publisher.send(completion: .finished)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("DropWhile"),
                                          .completion(.finished)])

        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("DropWhile"),
                                          .completion(.finished)])
    }

    func testCancelAlreadyCancelled() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let dropWhile = publisher.drop(while: { _ in true })
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })

        dropWhile.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(downstreamSubscription).cancel()

        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])

        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(tracking.history, [.subscription("DropWhile")])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = { deinitCounter += 1 }

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let dropWhile = passthrough.drop(while: { _ in true })
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            dropWhile.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        XCTAssertEqual(deinitCounter, 0)

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let dropWhile = passthrough.drop(while: { _ in true })
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            dropWhile.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 0)

        var subscription: Subscription?

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let dropWhile = passthrough.drop(while: { _ in true })
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            dropWhile.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 0)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 0)
    }
}
