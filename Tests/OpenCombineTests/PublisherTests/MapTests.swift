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

@available(macOS 10.15, *)
final class MapTests: XCTestCase {
    static let allTests = [
        ("testEmpty", testEmpty),
        ("testError", testError),
        ("testRange", testRange),
        ("testNoDemand", testNoDemand),
        ("testDemandSubscribe", testDemandSubscribe),
        ("testDemandSend", testDemandSend),
        ("testCompletion", testCompletion),
        ("testCancel", testCancel),
        ("testCancelAlreadyCancelled", testCancelAlreadyCancelled)
    ]

    func testEmpty() {
        // Given
        let tracking = TrackingSubscriberBase<Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()
        // When
        publisher.map { $0 * 2 }.subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty)])
    }

    func testError() {
        // Given
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        let publisher = PassthroughSubject<Int, TestingError>()
        // When
        publisher.map { $0 * 2 }.subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        // Then
        XCTAssertEqual(tracking.history, [
            .subscription(Subscriptions.empty),
            .completion(Subscribers.Completion<TestingError>.failure(expectedError))
        ])
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
            .subscription(Subscriptions.empty),
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
        // Given
        let expectedReceiveValueDemand = 4
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.map { $0 * 2 }
        let tracking = TrackingSubscriber(
            receiveValue: { _ in .max(expectedReceiveValueDemand) }
        )
        // When
        map.subscribe(tracking)
        // Then
        XCTAssertEqual(publisher.send(0), .max(expectedReceiveValueDemand))
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
            [.subscription(Subscriptions.empty), .completion(.finished)]
        )
    }

    func testCancel() throws {
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
}
