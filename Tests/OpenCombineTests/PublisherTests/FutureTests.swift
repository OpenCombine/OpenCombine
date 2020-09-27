//
//  FutureTests.swift
//  
//
//  Created by Max Desiatov on 24/11/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class FutureTests: XCTestCase {
    private typealias Sut = Future<Int, TestingError>

    func testFutureSuccess() {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }

        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            subscription.request(.unlimited)
        })
        future.subscribe(subscriber)

        promise?(.success(42))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(42),
            .completion(.finished)
        ])
    }

    func testFutureFailure() {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }

        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                subscription.request(.unlimited)
            }, receiveValue: { _ in
                XCTFail("no value should be returned")
                return .none
            }
        )
        future.subscribe(subscriber)

        let error = TestingError(description: "\(#function)")
        promise?(.failure(error))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .completion(.failure(error))
        ])
    }

    func testResolvingMultipleTimes() {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }

        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            subscription.request(.unlimited)
        })
        future.subscribe(subscriber)

        promise?(.success(42))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(42),
            .completion(.finished)
        ])

        promise?(.success(41))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(42),
            .completion(.finished)
        ])
    }

    func testCancellation() {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }

        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            subscription.request(.unlimited)
        })
        future.subscribe(subscriber)

        subscriber.subscriptions.forEach { $0.cancel() }
        subscriber.subscriptions.forEach { $0.cancel() }
        subscriber.subscriptions.forEach { $0.request(.max(1)) }

        promise?(.success(42))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future")
        ])
    }

    func testSubscribeAfterSuccessfulResolution() {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }
        promise?(.success(42))

        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            subscription.request(.unlimited)
        })
        future.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(42),
            .completion(.finished)
        ])
    }

    func testSubscribeAfterFailure() {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }
        promise?(.failure(.oops))

        let subscriber = TrackingSubscriber()
        future.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Future"),
                                            .completion(.failure(.oops))])
    }

    func testCrashesOnZeroDemand() throws {
        let future = Sut { _ in }

        var downstreamSubscription: Subscription?
        let subscriber = TrackingSubscriber(
            receiveSubscription: {
                downstreamSubscription = $0
            }
        )
        future.subscribe(subscriber)

        try self.assertCrashes {
            try XCTUnwrap(downstreamSubscription).request(.none)
        }
    }

    func testValueRecursion() {
        var promise: Sut.Promise?
        let future = Sut { promise = $0 }

        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            subscription.request(.unlimited)
        }, receiveValue: {
            promise?(.success($0 + 1))
            return .none
        })
        future.subscribe(subscriber)

        promise?(.success(0))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(0),
            .completion(.finished)
        ])
    }

    func testFinishedRecursion() {
        var promise: Sut.Promise?
        let future = Sut { promise = $0 }

        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            subscription.request(.unlimited)
        }, receiveCompletion: {
            guard case .finished = $0 else {
                XCTFail("future in \(#function) is not expected to fail")
                return
            }
            promise?(.success(42))
        })
        future.subscribe(subscriber)

        promise?(.success(0))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(0),
            .completion(.finished)
        ])
    }

    func testFailureRecursion() {
        var promise: Sut.Promise?
        let future = Sut { promise = $0 }

        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            subscription.request(.unlimited)
        }, receiveCompletion: {
            guard case .failure = $0 else {
                XCTFail("future in \(#function) is expected to fail")
                return
            }
            promise?(.success(42))
        })
        future.subscribe(subscriber)

        let error = TestingError(description: "\(#function)")

        promise?(.failure(error))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .completion(.failure(error))
        ])
    }

    func testStartsImmediately() {
        var hasStarted = false
        _ = Sut { _ in hasStarted = true }
        XCTAssertTrue(hasStarted)
    }

    func testWaitsForDemandSuccess() {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }

        var downstreamSubscription: Subscription?
        let subscriber = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        future.subscribe(subscriber)

        promise?(.success(42))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future")
        ])

        downstreamSubscription?.request(.max(1))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(42),
            .completion(.finished)
        ])
    }

    func testReleasesEverythingOnTermination() {

        enum TerminationReason: CaseIterable {
            case cancelled
            case finished
            case failed
        }

        for reason in TerminationReason.allCases {
            weak var weakSubscriber: TrackingSubscriber?
            weak var weakFuture: Sut?
            weak var weakSubscription: AnyObject?

            do {
                var promise: Sut.Promise?
                let future = Sut { promise = $0 }
                do {
                    let subscriber = TrackingSubscriber(
                        receiveSubscription: {
                            weakSubscription = $0 as AnyObject
                            $0.request(.max(1))
                        }
                    )
                    weakSubscriber = subscriber
                    weakFuture = future

                    future.subscribe(subscriber)
                }

                switch reason {
                case .cancelled:
                    (weakSubscription as? Subscription)?.cancel()
                case .finished:
                    promise?(.success(1))
                case .failed:
                    promise?(.failure(.oops))
                }

                XCTAssertNil(weakSubscriber, "Subscriber leaked - \(reason)")
                XCTAssertNil(weakSubscription, "Subscription leaked - \(reason)")
            }

            XCTAssertNil(weakFuture, "Future leaked - \(reason)")
        }
    }

    func testConduitReflection() throws {
        try testSubscriptionReflection(
            description: "Future",
            customMirror: expectedChildren(
                ("parent", .contains("Future")),
                ("downstream", .contains("TrackingSubscriberBase")),
                ("hasAnyDemand", "false"),
                ("subject", .contains("Future"))
            ),
            playgroundDescription: "Future",
            sut: Sut { _ in }
        )
    }
}
