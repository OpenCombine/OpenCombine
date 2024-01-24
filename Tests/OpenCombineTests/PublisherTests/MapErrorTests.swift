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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

    func testMapErrorReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "MapError",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "MapError",
                           subscriberIsAlsoSubscription: false,
                           { $0.mapError { $0 } })
    }

    func testMapErrorReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(0)],
                                                              demand: .max(42)),
                                           { $0.mapError(unreachable) })
    }

    func testMapErrorReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.mapError(unreachable) }
        )
    }

    func testMapErrorLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: true,
                          { $0.mapError(OtherError.init) })
    }
}

private struct OtherError: EquatableError {
    let original: EquatableError

    init(_ original: EquatableError) {
        self.original = original
    }

    func isEqual(_ other: EquatableError) -> Bool {
        guard let other = other as? OtherError else { return false }
        return original.isEqual(other.original)
    }
}
