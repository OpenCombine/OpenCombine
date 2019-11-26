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

        promise?(.success(42))

        XCTAssertEqual(subscriber.history, [
            .subscription("Future")
        ])
    }

    func testSubscribeAfterResolution() {
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

    func testCrashesOnZeroDemand() {
        let future = Sut { _ in }

        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            self.assertCrashes {
                subscription.request(.none)
            }
        })
        future.subscribe(subscriber)
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

    func testWaitsForRequest() {
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
}
