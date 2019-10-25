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
    func testReceiveValueBeforeSubscription<Value, Operator: Publisher>(
        value: Value,
        shouldCrash: Bool,
        _ makeOperator: (CustomConnectablePublisherBase<Value, Never>) -> Operator
    ) {

        let publisher = CustomConnectablePublisherBase<Value, Never>(subscription: nil)
        let drop = makeOperator(publisher)
        let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>()
        drop.subscribe(tracking)
        if shouldCrash {
            assertCrashes {
                XCTAssertEqual(publisher.send(value), .none)
            }
        } else {
            XCTAssertEqual(publisher.send(value), .none)
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

        let thirdSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)

        XCTAssertEqual(thirdSubscription.history, [.cancelled])
    }
}

// swiftlint:disable generic_type_name

func shouldNotBeCalled<S, T>(
    file: StaticString = #file,
    line: UInt = #line
) -> (S, T) -> S {
    return { s, _ in
        XCTFail("should not be called", file: file, line: line)
        return s
    }
}

func shouldNotBeCalled<T>(
    file: StaticString = #file, line: UInt = #line
) -> (T, T) -> Bool {
    return { _, _ in
        XCTFail("Should not be called", file: file, line: line)
        return true
    }
}

func shouldNotBeCalled<T>(
    file: StaticString = #file, line: UInt = #line
) -> (T) -> Bool {
    return { _ in
        XCTFail("Should not be called", file: file, line: line)
        return true
    }
}

func unreachable<T>(_: T) -> Never {
    fatalError("unreachable")
}

// swiftlint:enable generic_type_name
