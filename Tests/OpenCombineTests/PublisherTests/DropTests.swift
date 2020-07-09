//
//  DropTests.swift
//
//
//  Created by Sven Weidauer on 03.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class DropTests: XCTestCase {

    func testDroppingTwoElements() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(42),
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.dropFirst(2) })

        XCTAssertEqual(helper.tracking.history, [.subscription("Drop")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(44))])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .max(3))
        XCTAssertEqual(helper.publisher.send(4), .max(3))
        XCTAssertEqual(helper.publisher.send(5), .max(3))

        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .value(3),
                                                 .value(4),
                                                 .value(5)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(44))])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .value(3),
                                                 .value(4),
                                                 .value(5),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(44))])

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .value(3),
                                                 .value(4),
                                                 .value(5),
                                                 .completion(.finished),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(44))])
    }

    func testDroppingNothing() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.dropFirst(0) })

        XCTAssertEqual(helper.tracking.history, [.subscription("Drop")])
        XCTAssertEqual(helper.subscription.history, [])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(42))

        XCTAssertEqual(helper.tracking.history, [.subscription("Drop")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42))])

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3)])
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .completion(.failure(.oops))])
    }

    func testDropNegativeNumberOfItemsCrash() {
        let publisher = CustomPublisher(subscription: CustomSubscription())
        let drop = publisher.dropFirst(-1)
        let tracking = TrackingSubscriber()

        assertCrashes {
            drop.subscribe(tracking)
        }
    }

    func testCrashesOnZeroDemand() {
        let publisher = CustomPublisher(subscription: CustomSubscription())
        let drop = publisher.dropFirst()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.none) })
        assertCrashes {
            drop.subscribe(tracking)
        }
    }

    func testReceiveSubscriptionTwice() throws {
        let subscription1 = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription1)
        let drop = publisher.dropFirst()
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(2)) })

        drop.subscribe(tracking)

        XCTAssertEqual(subscription1.history, [.requested(.max(3))])

        let subscription2 = CustomSubscription()

        try XCTUnwrap(publisher.subscriber).receive(subscription: subscription2)

        XCTAssertEqual(subscription2.history, [.cancelled])

        try XCTUnwrap(publisher.subscriber).receive(subscription: subscription1)

        XCTAssertEqual(subscription1.history, [.requested(.max(3)),
                                               .cancelled])
    }

    func testDropReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([.subscription("Drop"), .value(0)],
                               demand: .max(42)),
            { $0.dropFirst(0) }
        )
    }

    func testDropReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("Drop"), .completion(.finished)]),
            { $0.dropFirst(0) }
        )
    }

    func testDropRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.dropFirst(0) })
    }

    func testDropCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.dropFirst(0) })
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.dropFirst() }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled])
    }

    func testRequestsFromUpstreamThenSendsSubscriptionDownstream() {
        var didReceiveSubscription = false
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.dropFirst()
        let tracking = TrackingSubscriber(
            receiveSubscription: { _ in
                XCTAssertEqual(subscription.history, [])
                didReceiveSubscription = true
            }
        )
        XCTAssertFalse(didReceiveSubscription)
        XCTAssertEqual(subscription.history, [])

        drop.subscribe(tracking)

        XCTAssertTrue(didReceiveSubscription)
        XCTAssertEqual(subscription.history, [.requested(.max(1))])
    }

    func testReusableSubscription() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.dropFirst(3) })

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.tracking.history, [.subscription("Drop")])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .completion(.finished)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .completion(.finished)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(312))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(100))

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .completion(.finished)])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(secondSubscription.history, [.requested(.max(413))])
        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .max(3))

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(secondSubscription.history, [.requested(.max(413))])
        XCTAssertEqual(helper.tracking.history, [.subscription("Drop"),
                                                 .completion(.finished),
                                                 .value(4)])
    }

    func testLateSubscription() throws {

        // This publisher doesn't send a subscription when it receives a subscriber
        let publisher = CustomPublisher(subscription: nil)
        let drop = publisher.dropFirst(4)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(10)) })

        drop.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Drop")])

        let subscription = CustomSubscription()
        try XCTUnwrap(publisher.subscriber).receive(subscription: subscription)

        XCTAssertEqual(subscription.history, [.requested(.max(14))])
        XCTAssertEqual(tracking.history, [.subscription("Drop")])
    }

    func testDropLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.dropFirst(42) })
    }

    func testDropReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "Drop",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "Drop",
                           { $0.dropFirst(42) })
    }
}
