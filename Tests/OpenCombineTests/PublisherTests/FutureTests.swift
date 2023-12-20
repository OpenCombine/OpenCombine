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

// swiftlint:enable generic_type_name

@available(macOS 10.15, iOS 13.0, *)
final class FutureTests: XCTestCase {
    private typealias Sut = Future<Int, TestingError>

    private func assertParent(of futureSubscription: Subscription, isNil: Bool) {

        let parent: Mirror.Child
        do {
            parent = try XCTUnwrap(
                Mirror(reflecting: futureSubscription)
                    .children
                    .first { $0.label == "parent" }
            )
        } catch {
            XCTFail("Missing 'parent' property in \(futureSubscription)")
            return
        }


        // FIXME: This will fail on compatibility test when env is macOS 13 + Xcode 15.1. Can't reproduce this on macOS 12 and macOS 14
        #if OPENCOMBINE_COMPATIBILITY_TEST && os(macOS)
        guard ProcessInfo().operatingSystemVersion.majorVersion != 13 else {
            return
        }
        #endif
        let parentAsSut = parent.value as? Sut
        if isNil {
            XCTAssertNil(parentAsSut)
        } else {
            XCTAssertNotNil(parentAsSut)
        }
    }

    func testFutureSuccess() throws {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }

        var downstreamSubscription: Subscription?
        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            downstreamSubscription = subscription
            subscription.request(.unlimited)
        })
        future.subscribe(subscriber)

        let unwrappedDownstreamSubscription = try XCTUnwrap(downstreamSubscription)

        self.assertParent(of: unwrappedDownstreamSubscription, isNil: false)

        subscriber.onValue = { _ in
            self.assertParent(of: unwrappedDownstreamSubscription, isNil: false)
        }

        promise?(.success(42))

        self.assertParent(of: unwrappedDownstreamSubscription, isNil: true)

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(42),
            .completion(.finished)
        ])
    }

    func testFutureFailure() throws {
        var promise: Sut.Promise?

        let future = Sut { promise = $0 }

        var downstreamSubscription: Subscription?
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                downstreamSubscription = subscription
                subscription.request(.unlimited)
            }, receiveValue: { _ in
                XCTFail("no value should be returned")
                return .none
            }
        )
        future.subscribe(subscriber)

        let unwrappedDownstreamSubscription = try XCTUnwrap(downstreamSubscription)

        self.assertParent(of: unwrappedDownstreamSubscription, isNil: false)

        subscriber.onFailure = { _ in
            self.assertParent(of: unwrappedDownstreamSubscription, isNil: false)
        }

        let error = TestingError(description: "\(#function)")
        promise?(.failure(error))

        self.assertParent(of: unwrappedDownstreamSubscription, isNil: true)

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

    func testWaitsForDemandSuccess() throws {
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

        let unwrappedDownstreamSubscription = try XCTUnwrap(downstreamSubscription)

        self.assertParent(of: unwrappedDownstreamSubscription, isNil: false)

        subscriber.onValue = { _ in
            self.assertParent(of: unwrappedDownstreamSubscription, isNil: false)
        }

        unwrappedDownstreamSubscription.request(.max(1))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future"),
            .value(42),
            .completion(.finished)
        ])

        assertParent(of: unwrappedDownstreamSubscription, isNil: false)
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

        try testSubscriptionReflection(
            description: "Future",
            customMirror: expectedChildren(
                ("parent", "nil"),
                ("downstream", "nil"),
                ("hasAnyDemand", "false"),
                ("subject", "nil")
            ),
            playgroundDescription: "Future",
            sut: Sut { promise in promise(.failure(.oops)) }
        )
    }
}
