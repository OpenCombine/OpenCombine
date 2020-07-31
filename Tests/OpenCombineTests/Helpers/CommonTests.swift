//
//  CommonTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
extension XCTest {

    enum ValueBeforeSubscriptionBehavior<Value, Failure: Error> {
        case crash
        case history([TrackingSubscriberBase<Value, Failure>.Event],
                     demand: Subscribers.Demand,
                     comparator: (Value, Value) -> Bool)
    }

    func testReceiveValueBeforeSubscription<Value, Operator: Publisher>(
        value: Value,
        expected: ValueBeforeSubscriptionBehavior<Operator.Output, Operator.Failure>,
        _ makeOperator: (CustomConnectablePublisherBase<Value, Never>) -> Operator
    ) {
        let publisher = CustomConnectablePublisherBase<Value, Never>(subscription: nil)
        let operatorPublisher = makeOperator(publisher)
        let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>(
            receiveValue: { _ in .max(42) }
        )
        operatorPublisher.subscribe(tracking)
        switch expected {
        case .crash:
            assertCrashes {
                _ = publisher.send(value)
            }
        case let .history(history, demand, comparator):
            XCTAssertEqual(publisher.send(value), demand)
            tracking.assertHistoryEqual(history, valueComparator: comparator)
        }
    }

    enum CompletionBeforeSubscriptionBehavior<Value, Failure: Error> {
        case crash
        case history([TrackingSubscriberBase<Value, Failure>.Event],
                     comparator: (Value, Value) -> Bool)
    }

    func testReceiveCompletionBeforeSubscription<Value, Operator: Publisher>(
        inputType: Value.Type,
        expected: CompletionBeforeSubscriptionBehavior<Operator.Output, Operator.Failure>,
        _ makeOperator: (CustomConnectablePublisherBase<Value, Never>) -> Operator
    ) {

        let publisher = CustomConnectablePublisherBase<Value, Never>(subscription: nil)
        let operatorPublisher = makeOperator(publisher)
        let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>()
        operatorPublisher.subscribe(tracking)

        switch expected {
        case .crash:
            assertCrashes {
                publisher.send(completion: .finished)
            }
        case let .history(history, comparator: comparator):
            publisher.send(completion: .finished)
            tracking.assertHistoryEqual(history, valueComparator: comparator)
        }
    }

    func testRequestBeforeSubscription<Value, Operator: Publisher>(
        inputType: Value.Type,
        shouldCrash: Bool,
        _ makeOperator: (CustomConnectablePublisherBase<Value, Never>) -> Operator
    ) {

        let publisher = CustomConnectablePublisherBase<Value, Never>(subscription: nil)
        let operatorPublisher = makeOperator(publisher)
        let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>()
        operatorPublisher.subscribe(tracking)

        guard let subscription = publisher.erasedSubscriber as? Subscription else {
            XCTFail("The subscriber must also be a subscription")
            return
        }

        if shouldCrash {
            assertCrashes {
                subscription.request(.max(1))
            }
        } else {
            subscription.request(.max(1))
        }
    }

    func testCancelBeforeSubscription<Value, Operator: Publisher>(
        inputType: Value.Type,
        shouldCrash: Bool,
        _ makeOperator: (CustomConnectablePublisherBase<Value, Never>) -> Operator
    ) {

        let publisher = CustomConnectablePublisherBase<Value, Never>(subscription: nil)
        let operatorPublisher = makeOperator(publisher)
        let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>()
        operatorPublisher.subscribe(tracking)

        guard let subscription = publisher.erasedSubscriber as? Subscription else {
            XCTFail("The subscriber must also be a subscription")
            return
        }

        if shouldCrash {
            assertCrashes {
                subscription.cancel()
            }
        } else {
            subscription.cancel()
        }
    }

    func testReceiveSubscriptionTwice<Operator: Publisher>(
        _ makeOperator: (CustomPublisher) -> Operator
    ) throws where Operator.Output: Equatable {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: makeOperator
        )

        XCTAssertEqual(helper.subscription.history, [])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.cancelled, .cancelled])
    }
}

@available(macOS 10.15, iOS 13.0, *)
extension XCTestCase.ValueBeforeSubscriptionBehavior where Value: Equatable {
    static func history(
        _ history: [TrackingSubscriberBase<Value, Failure>.Event],
        demand: Subscribers.Demand
    ) -> XCTestCase.ValueBeforeSubscriptionBehavior<Value, Failure> {
        return .history(history, demand: demand, comparator: ==)
    }
}

@available(macOS 10.15, iOS 13.0, *)
extension XCTestCase.CompletionBeforeSubscriptionBehavior where Value: Equatable {
    static func history(
        _ history: [TrackingSubscriberBase<Value, Failure>.Event]
    ) -> XCTestCase.CompletionBeforeSubscriptionBehavior<Value, Failure> {
        return .history(history, comparator: ==)
    }
}

// swiftlint:disable generic_type_name

func shouldNotBeCalled<S, T>() -> (S, T) -> S {
    return { s, _ in
        XCTFail("should not be called")
        return s
    }
}

func shouldNotBeCalled<T>() -> (T, T) -> Bool {
    return { _, _ in
        XCTFail("Should not be called")
        return true
    }
}

func shouldNotBeCalled<T>() -> (T) -> Bool {
    return { _ in
        XCTFail("Should not be called")
        return true
    }
}

func unreachable<T>(_: T) -> Never {
    fatalError("unreachable")
}

func unreachable() -> Never {
    fatalError("unreachable")
}

// swiftlint:enable generic_type_name
