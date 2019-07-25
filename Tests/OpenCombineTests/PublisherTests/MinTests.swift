//
//  ComparisonTests.swift
//  OpenCombine
//
//  Created by Ilija Puaca on 22/7/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MinTests: XCTestCase {

    static let allTests = [
        ("testSendsCorrectValue", testSendsCorrectValue),
        ("testCustomMinSendsCorrectValue", testCustomMinSendsCorrectValue),
        ("testCountWaitsUntilFinishedToSend", testCountWaitsUntilFinishedToSend),
        ("testAddingSubscriberRequestsUnlimitedDemand",
         testAddingSubscriberRequestsUnlimitedDemand),
        ("testReceivesSubscriptionBeforeRequestingUpstream",
         testReceivesSubscriptionBeforeRequestingUpstream),
        ("testEmpty", testEmpty),
        ("testError", testError),
        ("testTryMinFailureBecauseOfThrow", testTryMinFailureBecauseOfThrow),
        ("testTryMinFailureOnCompletion", testTryMinFailureOnCompletion),
        ("testRange", testRange),
        ("testNoDemand", testNoDemand),
        ("testDemandSubscribe", testDemandSubscribe),
        ("testDemandSend", testDemandSend),
        ("testCompletion", testCompletion),
        ("testMinCancel", testMinCancel),
        ("testTryMinCancel", testTryMinCancel),
        ("testCancelAlreadyCancelled", testCancelAlreadyCancelled),
        ("testLifecycle", testLifecycle),
        ("testMinOperatorSpecializationForMin", testMinOperatorSpecializationForMin),
        ("testTryMinOperatorSpecializationForMin",
         testTryMinOperatorSpecializationForMin),
        ("testMinOperatorSpecializationForTryMin",
         testMinOperatorSpecializationForTryMin),
        ("testTryMinOperatorSpecializationForTryMin",
         testTryMinOperatorSpecializationForTryMin)
    ]

    func testSendsCorrectValue() {
        // Given
        let expectedValue = -Int.max
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let min = publisher.min()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(42)) })
        // When
        min.subscribe(tracking)
        [5, 0, expectedValue, -5, Int.max].forEach { _ = publisher.send($0) }
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(expectedValue),
                                          .completion(.finished)])
    }

    func testCustomMinSendsCorrectValue() {
        // Given
        let expectedValue = Int.max
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let min = publisher.min(by: >)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(42)) })
        // When
        min.subscribe(tracking)
        [5, 0, expectedValue, -5, -Int.max].forEach { _ = publisher.send($0) }
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(expectedValue),
                                          .completion(.finished)])
    }

    func testCountWaitsUntilFinishedToSend() {
        // Given
        let expectedValue = 0
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let minPublisher = publisher.min()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(42)) })
        // When
        minPublisher.subscribe(tracking)
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
        let minPublisher = publisher.min()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.max(42))
            downstreamSubscription = $0
        }, receiveValue: { _ in .max(4) })
        // When
        minPublisher.subscribe(tracking)
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
        let minPublisher = publisher.min()
        let tracking = TrackingSubscriber()
        // When
        XCTAssertEqual(subscription.history, [])
        minPublisher.subscribe(tracking)
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
        let minPublisher = publisher.min()
        let tracking = TrackingSubscriber(receiveSubscription: { _ in
            receiveOrder.append(receiveDownstream)
        })
        // When
        minPublisher.subscribe(tracking)
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
        publisher.min().subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison")])
    }

    func testError() {
        // Given
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        let publisher = CustomPublisher(subscription: CustomSubscription())
        // When
        publisher.min().subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        publisher.send(completion: .failure(expectedError))
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .completion(.failure(expectedError))])
    }

    func testTryMinFailureBecauseOfThrow() {
        // Given
        var counter = 0 // How many times is the comparison called?

        let expectedError = "too much" as TestingError
        let publisher = PassthroughSubject<Int, Error>()
        let min = publisher.tryMin { lhs, rhs -> Bool in
            guard lhs != 100, rhs != 100 else { throw expectedError }

            counter += 1
            return lhs < rhs
        }
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        // When
        publisher.send(6)
        min.subscribe(tracking)
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

    func testTryMinFailureOnCompletion() {
        let publisher = PassthroughSubject<Int, Error>()
        let min = publisher.tryMin(by: <)

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        min.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        publisher.send(2)

        XCTAssertEqual(tracking.history, [.subscription("TryComparison"),
                                          .completion(.failure(TestingError.oops))])
    }

    func testRange() {
        // Given
        let publisher = PassthroughSubject<Int, TestingError>()
        let min = publisher.min()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        // When
        publisher.send(1)
        min.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(completion: .finished)
        publisher.send(5)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(2),
                                          .completion(.finished)])
    }

    func testNoDemand() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let min = publisher.min()
        let tracking = TrackingSubscriber()
        // When
        min.subscribe(tracking)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testDemandSubscribe() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let min = publisher.min()
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(42)) }
        )
        // When
        min.subscribe(tracking)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testDemandSend() {
        // Given
        var subscriberDemand = 4
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let min = publisher.min()
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in .max(subscriberDemand) }
        )

        // When
        min.subscribe(tracking)
        // Then
        XCTAssertEqual(publisher.send(0), .none)
        subscriberDemand = 120
        XCTAssertEqual(publisher.send(0), .none)
    }

    func testCompletion() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let min = publisher.min()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        // When
        min.subscribe(tracking)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .completion(.finished)])
    }

    func testMinCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let min = publisher.min()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        min.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        _ = publisher.send(1)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testTryMinCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let min = publisher.tryMin(by: <)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Error>(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        min.subscribe(tracking)
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
        let min = publisher.min()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        min.subscribe(tracking)
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
            let min = passthrough.min()
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            min.subscribe(emptySubscriber)
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
            let min = passthrough.min()
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            min.subscribe(emptySubscriber)
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
            let min = passthrough.min()
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            min.subscribe(emptySubscriber)
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

    func testMinOperatorSpecializationForMin() {
        // Given
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let min1 = publisher.min()
        let min2 = min1.min()
        // When
        min2.subscribe(tracking)
        publisher.send(6)
        publisher.send(2)
        publisher.send(4)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("Comparison"),
                                          .value(2),
                                          .completion(.finished)])
    }

    func testTryMinOperatorSpecializationForMin() {
        // Given
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let min = publisher.min()
        let tryMin = min.tryMin { lhs, rhs -> Bool in
            guard lhs != 0, rhs != 0 else { throw TestingError.oops }
            return lhs < rhs
        }
        // When
        tryMin.subscribe(tracking)
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
                                          .value(0),
                                          .completion(.finished)])
    }

    func testMinOperatorSpecializationForTryMin() {
        // Given
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let expectedError = TestingError.oops
        let tryMin = publisher.tryMin { lhs, rhs -> Bool in
            guard lhs != 0, rhs != 0 else { throw expectedError }
            return lhs < rhs
        }
        let min = tryMin.min()
        // When
        min.subscribe(tracking)
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

    func testTryMinOperatorSpecializationForTryMin() {
        // Given
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let expectedError = TestingError.oops
        let tryMin1 = publisher.tryMin { lhs, rhs -> Bool in
            guard lhs != 0, rhs != 0 else { throw expectedError }
            return lhs < rhs
        }
        let tryMin2 = tryMin1.tryMin(by: <)
        // When
        tryMin2.subscribe(tracking)
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
