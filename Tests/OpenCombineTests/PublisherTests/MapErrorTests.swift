//
//  MapErrorTests.swift
//  
//
//  Created by Joseph Spadafora on 7/4/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MapErrorTests: XCTestCase {

    func testEmpty() {
        // Given
        let tracking = TrackingSubscriberBase<Int, OtherError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "MapError")
            }
        )
        // When
        publisher.mapError(OtherError.init).subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject")])
    }

    func testError() {
        // Given
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriberBase<Int, OtherError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        // When
        publisher.mapError(OtherError.init).subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        publisher.send(completion: .failure(expectedError))
        // Then
        XCTAssertEqual(tracking.history, [
            .subscription("CustomSubscription"),
            .completion(.failure(OtherError(expectedError))),
            .completion(.failure(OtherError(expectedError)))
        ])
    }

    func testRange() {
        // Given
        let publisher = PassthroughSubject<Int, TestingError>()
        let mapError = publisher.mapError(OtherError.init)
        let tracking = TrackingSubscriberBase<Int, OtherError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        // When
        publisher.send(1)
        mapError.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(completion: .finished)
        publisher.send(5)
        // Then
        XCTAssertEqual(tracking.history, [
            .subscription("PassthroughSubject"),
            .value(2),
            .value(3),
            .completion(.finished)
        ])
    }

    func testNoDemand() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let mapError = publisher.mapError(OtherError.init)
        let tracking = TrackingSubscriberBase<Int, OtherError>()
        // When
        mapError.subscribe(tracking)
        // Then
        XCTAssertTrue(subscription.history.isEmpty)
    }

    func testDemandSubscribe() {
        // Given
        let expectedSubscribeDemand = 42
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let mapError = publisher.mapError(OtherError.init)
        let tracking = TrackingSubscriberBase<Int, OtherError>(
            receiveSubscription: { $0.request(.max(expectedSubscribeDemand)) }
        )
        // When
        mapError.subscribe(tracking)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.max(expectedSubscribeDemand))])
    }

    func testDemandSend() {
        // Given
        let expectedReceiveValueDemand = 4
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let mapError = publisher.mapError(OtherError.init)
        let tracking = TrackingSubscriberBase<Int, OtherError>(
            receiveValue: { _ in .max(expectedReceiveValueDemand) }
        )
        // When
        mapError.subscribe(tracking)
        // Then
        XCTAssertEqual(publisher.send(0), .max(expectedReceiveValueDemand))
    }

    func testCompletion() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let mapError = publisher.mapError(OtherError.init)
        let tracking = TrackingSubscriberBase<Int, OtherError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        // When
        mapError.subscribe(tracking)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(
            tracking.history,
            [.subscription("CustomSubscription"), .completion(.finished)]
        )
    }

    func testCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let mapError = publisher.mapError(OtherError.init)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, OtherError>(
            receiveSubscription: {
                $0.request(.unlimited)
                downstreamSubscription = $0
            }
        )
        // When
        mapError.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testCancelAlreadyCancelled() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let mapError = publisher.mapError(OtherError.init)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, OtherError>(
            receiveSubscription: {
                $0.request(.unlimited)
                downstreamSubscription = $0
            }
        )
        // When
        mapError.subscribe(tracking)
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
            let mapError = passthrough.mapError(OtherError.init)
            let emptySubscriber = TrackingSubscriberBase<Int, OtherError>(
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            mapError.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        XCTAssertEqual(deinitCounter, 1)

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let mapError = passthrough.mapError(OtherError.init)
            let emptySubscriber = TrackingSubscriberBase<Int, OtherError>(
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            mapError.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let mapError = passthrough.mapError(OtherError.init)
            let emptySubscriber = TrackingSubscriberBase<Int, OtherError>(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            mapError.subscribe(emptySubscriber)
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
}

private struct OtherError: Error {
    let original: Error

    init(_ original: Error) {
        self.original = original
    }
}
