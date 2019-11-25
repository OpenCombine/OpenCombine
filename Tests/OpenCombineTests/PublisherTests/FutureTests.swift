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
    private typealias SUT = Future<Int, TestingError>

    func testFutureSuccess() {
        var promise: SUT.Promise?

        let future = SUT { promise = $0 }

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
        var promise: SUT.Promise?

        let future = SUT { promise = $0 }

        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                subscription.request(.unlimited)
            }, receiveValue: { _ in
                XCTFail("no value should be returned")
                return .unlimited
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
        var promise: SUT.Promise?

        let future = SUT { promise = $0 }

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
        var promise: SUT.Promise?

        let future = SUT { promise = $0 }

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

    func testCancellationViaDeinit() {
        var isCompleted = false
        var outputValue: Int?
        var promise: SUT.Promise?

        let future = SUT { promise = $0 }

        var cancellable: AnyCancellable? = future.sink(receiveCompletion: { _ in
            isCompleted = true
        }, receiveValue: { value in
            outputValue = value
        })

        XCTAssertNotNil(cancellable)

        cancellable = nil

        promise?(.success(42))

        XCTAssertFalse(isCompleted)
        XCTAssertNil(outputValue)
    }
}
