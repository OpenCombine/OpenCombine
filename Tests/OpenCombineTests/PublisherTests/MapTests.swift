//
//  MapTests.swift
//
//
//  Created by Anton Nazarov on 25/06/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MapTests: XCTestCase {

    func testEmpty() {
        // Given
        let tracking = TrackingSubscriberBase<String, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "Map")
            }
        )
        // When
        publisher.map(String.init).subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject")])
    }

    func testError() {
        // Given
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        let publisher = CustomPublisher(subscription: CustomSubscription())
        // When
        publisher.map { $0 * 2 }.subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        publisher.send(completion: .failure(expectedError))
        // Then
        XCTAssertEqual(tracking.history, [
            .subscription("CustomSubscription"),
            .completion(.failure(expectedError)),
            .completion(.failure(expectedError))
        ])
    }

    func testTryMapFailureBecauseOfThrow() {
        var counter = 0 // How many times the transform is called?

        let publisher = PassthroughSubject<Int, Error>()
        let map = publisher.tryMap { value -> Int in
            counter += 1
            if value == 100 {
                throw "too much" as TestingError
            }
            return value * 2
        }
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.send(1)
        map.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(100)
        publisher.send(9)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryMap"),
                        .value(4),
                        .value(6),
                        .completion(.failure("too much" as TestingError))])

        XCTAssertEqual(counter, 3)
    }

    func testTryMapFailureOnCompletion() {

        let publisher = PassthroughSubject<Int, Error>()
        let map = publisher.tryMap { $0 * 2 }

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        map.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        publisher.send(2)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryMap"),
                        .completion(.failure(TestingError.oops))])
    }

    func testTryMapSuccess() {
        let publisher = PassthroughSubject<Int, Error>()
        let map = publisher.tryMap { $0 * 2 }

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        map.subscribe(tracking)
        publisher.send(completion: .finished)
        publisher.send(2)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryMap"),
                        .completion(.finished)])
    }

    func testRange() {
        // Given
        let publisher = PassthroughSubject<Int, TestingError>()
        let map = publisher.map { $0 * 2 }
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        // When
        publisher.send(1)
        map.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(completion: .finished)
        publisher.send(5)
        // Then
        XCTAssertEqual(tracking.history, [
            .subscription("PassthroughSubject"),
            .value(4),
            .value(6),
            .completion(.finished)
        ])
    }

    func testNoDemand() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.map { $0 * 2 }
        let tracking = TrackingSubscriber()
        // When
        map.subscribe(tracking)
        // Then
        XCTAssertTrue(subscription.history.isEmpty)
    }

    func testDemandSubscribe() {
        // Given
        let expectedSubscribeDemand = 42
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.map { $0 * 2 }
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(expectedSubscribeDemand)) }
        )
        // When
        map.subscribe(tracking)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.max(expectedSubscribeDemand))])
    }

    func testDemandSend() {
        var expectedReceiveValueDemand = 4
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.map { $0 * 2 }
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in .max(expectedReceiveValueDemand) }
        )

        map.subscribe(tracking)

        XCTAssertEqual(publisher.send(0), .max(4))

        expectedReceiveValueDemand = 120

        XCTAssertEqual(publisher.send(0), .max(120))
    }

    func testCompletion() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.map { $0 * 2 }
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        // When
        map.subscribe(tracking)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(
            tracking.history,
            [.subscription("CustomSubscription"), .completion(.finished)]
        )
    }

    func testMapCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.map { $0 * 2 }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        map.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send(1), .none)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testTryMapCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.tryMap { $0 * 2 }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Error>(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        map.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send(1), .none)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testCancelAlreadyCancelled() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.map { $0 * 2 }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        map.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(downstreamSubscription).cancel()
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled,
                                              .requested(.unlimited),
                                              .cancelled])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = { deinitCounter += 1 }

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let map = passthrough.map { $0 * 2 }
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            map.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        XCTAssertEqual(deinitCounter, 1)

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let map = passthrough.map { $0 * 2 }
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            map.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let map = passthrough.map { $0 * 2 }
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            map.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 1)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 1)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 2)
    }

    func testMapOperatorSpecializationForMap() {

        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let map1 = publisher.map { $0 * 2 }
        let map2 = map1.map { $0 + 1 }

        map2.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(5)
        publisher.send(completion: .finished)

        XCTAssert(map1.upstream === map2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject"),
                                          .value(5),
                                          .value(7),
                                          .value(11),
                                          .completion(.finished)])
    }

    func testTryMapOperatorSpecializationForMap() {
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let map1 = publisher.map { $0 * 2 }

        let tryMap2 = map1.tryMap { input -> Int in
            if input == 12 { throw TestingError.oops }
            return input + 1
        }

        tryMap2.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(5)

        XCTAssert(map1.upstream === tryMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11)])

        publisher.send(6)

        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11),
                                          .completion(.failure(TestingError.oops))])
    }

    func testMapOperatorSpecializationForTryMap() {
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let tryMap1 = publisher.tryMap { input -> Int in
            if input == 6 { throw TestingError.oops }
            return input * 2
        }

        let tryMap2 = tryMap1.map { $0 + 1 }

        tryMap2.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(5)

        XCTAssert(tryMap1.upstream === tryMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11)])

        publisher.send(6)

        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11),
                                          .completion(.failure(TestingError.oops))])
    }

    func testTryMapOperatorSpecializationForTryMap() {
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let tryMap1 = publisher.tryMap { input -> Int in
            if input == 6 { throw TestingError.oops }
            return input * 2
        }

        let tryMap2 = tryMap1.tryMap { $0 + 1 }

        tryMap2.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(5)

        XCTAssert(tryMap1.upstream === tryMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11)])

        publisher.send(6)

        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11),
                                          .completion(.failure(TestingError.oops))])
    }
}
