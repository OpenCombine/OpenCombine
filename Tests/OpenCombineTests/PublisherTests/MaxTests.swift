//
//  MaxTests.swift
//  OpenCombineTests
//
//  Created by Ilija Puaca on 24/7/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MaxTests: XCTestCase {

    static let allTests = [
        ("testSendsCorrectValue", testSendsCorrectValue),
        ("testCustomMaxSendsCorrectValue", testCustomMaxSendsCorrectValue),
        ("testCountWaitsUntilFinishedToSend", testCountWaitsUntilFinishedToSend),
        ("testAddingSubscriberRequestsUnlimitedDemand",
         testAddingSubscriberRequestsUnlimitedDemand),
        ("testReceivesSubscriptionBeforeRequestingUpstream",
         testReceivesSubscriptionBeforeRequestingUpstream),
        ("testEmpty", testEmpty),
        ("testError", testError),
        ("testTryMaxFailureBecauseOfThrow", testTryMaxFailureBecauseOfThrow),
        ("testTryMaxFailureOnCompletion", testTryMaxFailureOnCompletion),
        ("testRange", testRange),
        ("testNoDemand", testNoDemand),
        ("testDemandSubscribe", testDemandSubscribe),
        ("testDemandSend", testDemandSend),
        ("testCompletion", testCompletion),
        ("testMaxCancel", testMaxCancel),
        ("testTryMaxCancel", testTryMaxCancel),
        ("testCancelAlreadyCancelled", testCancelAlreadyCancelled),
        ("testLifecycle", testLifecycle),
        ("testMaxOperatorSpecializationForMax", testMaxOperatorSpecializationForMax),
        ("testTryMaxOperatorSpecializationForMax",
         testTryMaxOperatorSpecializationForMax),
        ("testMaxOperatorSpecializationForTryMax",
         testMaxOperatorSpecializationForTryMax),
        ("testTryMaxOperatorSpecializationForTryMax",
         testTryMaxOperatorSpecializationForTryMax)
    ]

    func testSendsCorrectValue() {
        // Given
        let expectedValue = Int.max
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.max()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(42)) })
        // When
        max.subscribe(tracking)
        [5, 0, expectedValue, -5, -Int.max].forEach { _ = publisher.send($0) }
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(expectedValue),
                                          .completion(.finished)])
    }

    func testCustomMaxSendsCorrectValue() {
        // Given
        let expectedValue = -Int.max
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.max(by: <)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(42)) })
        // When
        max.subscribe(tracking)
        [5, 0, expectedValue, -5, Int.max].forEach { _ = publisher.send($0) }
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(expectedValue),
                                          .completion(.finished)])
    }

    func testCountWaitsUntilFinishedToSend() {
        // Given
        let expectedValue = 42
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let maxPublisher = publisher.max()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(42)) })
        // When
        maxPublisher.subscribe(tracking)
        _ = publisher.send(4)
        XCTAssertEqual(tracking.history, [.subscription("Comparison")])

        _ = publisher.send(expectedValue)
        XCTAssertEqual(tracking.history, [.subscription("Comparison")])

        _ = publisher.send(6)
        XCTAssertEqual(tracking.history, [.subscription("Comparison")])

        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(expectedValue),
                                          .completion(.finished)])
    }

    func testDemand() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let maxPublisher = publisher.max()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.max(42))
            downstreamSubscription = $0
        }, receiveValue: { _ in .max(4) })
        // When
        maxPublisher.subscribe(tracking)
        // Then
        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(0), .none)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        downstreamSubscription?.request(.max(95))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled])

        downstreamSubscription?.request(.max(50))
        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled])
    }

    func testAddingSubscriberRequestsUnlimitedDemand() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let maxPublisher = publisher.max()
        let tracking = TrackingSubscriber()
        // When
        XCTAssertEqual(subscription.history, [])
        maxPublisher.subscribe(tracking)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testReceivesSubscriptionBeforeRequestingUpstream() {
        // Given
        let upstreamRequest = "Requested upstream subscription"
        let receiveDownstream = "Receive downstream"
        var receiveOrder: [String] = []

        let subscription = CustomSubscription(onRequest: { _ in
            receiveOrder.append(upstreamRequest)
        })
        let publisher = CustomPublisher(subscription: subscription)
        let maxPublisher = publisher.max()
        let tracking = TrackingSubscriber(receiveSubscription: { _ in
            receiveOrder.append(receiveDownstream)
        })
        // When
        maxPublisher.subscribe(tracking)
        // Then
        XCTAssertEqual(receiveOrder, [receiveDownstream, upstreamRequest])
    }

    func testEmpty() {
        // Given
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        let publisher = TrackingSubject<Int>(receiveSubscriber: {
            XCTAssertEqual(String(describing: $0), "Comparison")
        })
        // When
        publisher.max().subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison")])
    }

    func testError() {
        // Given
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        let publisher = CustomPublisher(subscription: CustomSubscription())
        // When
        publisher.max().subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        publisher.send(completion: .failure(expectedError))
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .completion(.failure(expectedError))])
    }

    func testTryMaxFailureBecauseOfThrow() {
        // Given
        var counter = 0 // How many times is the comparison called?

        let expectedError = "too much" as TestingError
        let publisher = PassthroughSubject<Int, Error>()
        let max = publisher.tryMax { lhs, rhs -> Bool in
            guard lhs != 100, rhs != 100 else { throw expectedError }

            counter += 1
            return lhs < rhs
        }
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        // When
        publisher.send(6)
        max.subscribe(tracking)
        publisher.send(2)
        publisher.send(4)
        publisher.send(100)
        publisher.send(1)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history,
                       [.subscription("TryComparison"),
                        .completion(.failure(expectedError))])
        XCTAssertEqual(counter, 1)
    }

    func testTryMaxFailureOnCompletion() {
        let publisher = PassthroughSubject<Int, Error>()
        let max = publisher.tryMax(by: <)

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        max.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        publisher.send(2)

        XCTAssertEqual(tracking.history, [.subscription("TryComparison"),
                                          .completion(.failure(TestingError.oops))])
    }

    func testRange() {
        // Given
        let expectedValue = 3
        let publisher = PassthroughSubject<Int, TestingError>()
        let max = publisher.max()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        // When
        publisher.send(1)
        max.subscribe(tracking)
        publisher.send(2)
        publisher.send(expectedValue)
        publisher.send(completion: .finished)
        publisher.send(5)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(expectedValue),
                                          .completion(.finished)])
    }

    func testNoDemand() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.max()
        let tracking = TrackingSubscriber()
        // When
        max.subscribe(tracking)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testDemandSubscribe() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.max()
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(42)) }
        )
        // When
        max.subscribe(tracking)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testDemandSend() {
        // Given
        var subscriberDemand = 4
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.max()
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in .max(subscriberDemand) }
        )

        // When
        max.subscribe(tracking)
        // Then
        XCTAssertEqual(publisher.send(0), .none)
        subscriberDemand = 120
        XCTAssertEqual(publisher.send(0), .none)
    }

    func testCompletion() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.max()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        // When
        max.subscribe(tracking)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .completion(.finished)])
    }

    func testMaxCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.max()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        max.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        _ = publisher.send(1)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testTryMaxCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.tryMax(by: <)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Error>(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        max.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        _ = publisher.send(1)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testCancelAlreadyCancelled() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let max = publisher.max()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        max.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(downstreamSubscription).cancel()
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testLifecycle() throws {
        // Given
        var deinitCounter = 0
        let onDeinit = { deinitCounter += 1 }
        // When
        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let max = passthrough.max()
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            max.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        // Then
        XCTAssertEqual(deinitCounter, 0)
        // When
        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let max = passthrough.max()
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            max.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }
        // Then
        XCTAssertEqual(deinitCounter, 0)

        // When
        var subscription: Subscription?
        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let max = passthrough.max()
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            max.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            passthrough.send(completion: .finished)
            XCTAssertEqual(emptySubscriber.inputs.count, 1)
            XCTAssertEqual(emptySubscriber.completions.count, 1)
            XCTAssertNotNil(subscription)
        }

        // Then
        XCTAssertEqual(deinitCounter, 0)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 0)
    }

    func testMaxOperatorSpecializationForMax() {
        // Given
        let expectedValue = 42
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let max1 = publisher.max()
        let max2 = max1.max()
        // When
        max2.subscribe(tracking)
        publisher.send(6)
        publisher.send(expectedValue)
        publisher.send(4)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(expectedValue),
                                          .completion(.finished)])
    }

    func testTryMaxOperatorSpecializationForMax() {
        // Given
        let expectedValue = 42
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let max = publisher.max()
        let tryMax = max.tryMax { lhs, rhs -> Bool in
            guard lhs != 0, rhs != 0 else { throw TestingError.oops }
            return lhs < rhs
        }
        // When
        tryMax.subscribe(tracking)
        publisher.send(6)
        publisher.send(2)
        publisher.send(4)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("TryComparison")])
        // When
        publisher.send(expectedValue)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("TryComparison"),
                                          .value(expectedValue),
                                          .completion(.finished)])
    }

    func testMaxOperatorSpecializationForTryMax() {
        // Given
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let expectedError = TestingError.oops
        let tryMax = publisher.tryMax { lhs, rhs -> Bool in
            guard lhs != 0, rhs != 0 else { throw expectedError }
            return lhs < rhs
        }
        let max = tryMax.max()
        // When
        max.subscribe(tracking)
        publisher.send(6)
        publisher.send(2)
        publisher.send(4)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison")])
        // When
        publisher.send(0)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .completion(.failure(expectedError))])
    }

    func testTryMaxOperatorSpecializationForTryMax() {
        // Given
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let expectedError = TestingError.oops
        let tryMax1 = publisher.tryMax { lhs, rhs -> Bool in
            guard lhs != 0, rhs != 0 else { throw expectedError }
            return lhs < rhs
        }
        let tryMax2 = tryMax1.tryMax(by: <)
        // When
        tryMax2.subscribe(tracking)
        publisher.send(6)
        publisher.send(2)
        publisher.send(4)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("TryComparison")])
        // When
        publisher.send(0)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("TryComparison"),
                                          .completion(.failure(expectedError))])
    }
}
