//
//  DropUntilOutputTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class DropUntilOutputTests: XCTestCase {

    func testOtherCompletesBeforeTriggering() {
        let otherSubscription = CustomSubscription()
        let otherPublisher = CustomPublisher(subscription: otherSubscription)
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(100),
            receiveValueDemand: .max(5),
            createSut: { $0.drop(untilOutputFrom: otherPublisher) }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("DropUntilOutput")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100))])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])

        otherPublisher.send(completion: .finished)
        otherPublisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("DropUntilOutput"),
                                                 .completion(.finished),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100)), .cancelled])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(otherPublisher.send(1000), .none)
        XCTAssertEqual(helper.publisher.send(4), .max(5))

        XCTAssertEqual(helper.tracking.history, [.subscription("DropUntilOutput"),
                                                 .completion(.finished),
                                                 .completion(.finished),
                                                 .value(4)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100)), .cancelled])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])
    }

    func testOtherFailsAfterTriggering() {
        let otherSubscription = CustomSubscription()
        let otherPublisher = CustomPublisher(subscription: otherSubscription)
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(5),
            createSut: { $0.drop(untilOutputFrom: otherPublisher) }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(otherPublisher.send(1000), .none)
        XCTAssertEqual(helper.publisher.send(2), .max(5))

        XCTAssertEqual(helper.tracking.history, [.subscription("DropUntilOutput"),
                                                 .value(2)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])

        otherPublisher.send(completion: .failure(.oops))
        otherPublisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("DropUntilOutput"),
                                                 .value(2)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])
    }

    func testDemand() throws {
        let subscription = CustomSubscription()
        let otherSubscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let otherPublisher = CustomPublisher(subscription: otherSubscription)
        let dropUntilOutput = publisher.drop(untilOutputFrom: otherPublisher)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { subscription in
                downstreamSubscription = subscription
            },
            receiveValue: { .max($0) }
        )
        dropUntilOutput.subscribe(tracking)

        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])
        XCTAssertEqual(tracking.history, [.subscription("DropUntilOutput")])

        try XCTUnwrap(downstreamSubscription).request(.max(4))

        XCTAssertEqual(subscription.history, [.requested(.max(4))])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])
        XCTAssertEqual(tracking.history, [.subscription("DropUntilOutput")])

        XCTAssertEqual(publisher.send(1), .none)
        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(otherPublisher.send(1000), .none)
        XCTAssertEqual(publisher.send(3), .max(3))
        XCTAssertEqual(publisher.send(4), .max(4))
        XCTAssertEqual(publisher.send(5), .max(5))
        XCTAssertEqual(publisher.send(6), .max(6))
        XCTAssertEqual(publisher.send(7), .max(7))

        XCTAssertEqual(subscription.history, [.requested(.max(4))])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])
        XCTAssertEqual(tracking.history, [.subscription("DropUntilOutput"),
                                          .value(3),
                                          .value(4),
                                          .value(5),
                                          .value(6),
                                          .value(7)])
    }

    func testCancelAlreadyCancelled() throws {
        let otherSubscription = CustomSubscription()
        let otherPublisher = CustomPublisher(subscription: otherSubscription)
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(5),
            createSut: { $0.drop(untilOutputFrom: otherPublisher) }
        )

        helper.subscription.onCancel = {
            XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])
        }

        otherSubscription.onCancel = {
            XCTAssertEqual(helper.subscription.history, [.requested(.max(2)), .cancelled])
        }

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(10))
        XCTAssertEqual(helper.publisher.send(1000), .none)
        helper.publisher.send(completion: .finished)

        let subscription2 = CustomSubscription()
        helper.publisher.send(subscription: subscription2)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(2)), .cancelled])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("DropUntilOutput")])
        XCTAssertEqual(subscription2.history, [.cancelled])
    }

    func testSubscribesToOtherFirst() {
        let subscription = CustomSubscription()
        let otherSubscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let otherPublisher = CustomPublisher(subscription: otherSubscription)
        let dropUntilOutput = publisher.drop(untilOutputFrom: otherPublisher)
        let tracking = TrackingSubscriber(
            receiveSubscription: { _ in
                XCTAssertNil(publisher.subscriber)
                XCTAssertNil(otherPublisher.subscriber)
                XCTAssertEqual(subscription.history, [])
                XCTAssertEqual(otherSubscription.history, [])
            }
        )

        otherPublisher.willSubscribe = { _, _ in
            XCTAssertNil(publisher.subscriber)
        }

        publisher.willSubscribe = { _, _ in
            XCTAssertNotNil(otherPublisher.subscriber)
        }

        dropUntilOutput.subscribe(tracking)
        tracking.cancel()
    }

    func testSubscribersHaveTheSameCombineIdentifier() {
        let subscription = CustomSubscription()
        let otherSubscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let otherPublisher = CustomPublisher(subscription: otherSubscription)
        let dropUntilOutput = publisher.drop(untilOutputFrom: otherPublisher)
        let tracking = TrackingSubscriber()
        dropUntilOutput.subscribe(tracking)

        XCTAssert(publisher.erasedSubscriber is CustomCombineIdentifierConvertible)
        XCTAssert(otherPublisher.erasedSubscriber is CustomCombineIdentifierConvertible)
        XCTAssertEqual(
            (publisher.erasedSubscriber as? CustomCombineIdentifierConvertible)?
                .combineIdentifier,
            (otherPublisher.erasedSubscriber as? CustomCombineIdentifierConvertible)?
                .combineIdentifier
        )
    }

    func testLateSubscription() throws {

        // This publisher doesn't send a subscription when it receives a subscriber
        let publisher = CustomPublisher(subscription: nil)
        let dropUntilOutput = publisher.drop(untilOutputFrom: Empty<Void, TestingError>())
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(10))
                $0.request(.max(4))
                $0.request(.none)
            }
        )

        dropUntilOutput.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("DropUntilOutput"),
                                          .completion(.finished)])

        let subscription = CustomSubscription()
        try XCTUnwrap(publisher.subscriber).receive(subscription: subscription)

        XCTAssertEqual(subscription.history, [.requested(.max(14))])
        XCTAssertEqual(tracking.history, [.subscription("DropUntilOutput"),
                                          .completion(.finished)])
    }

    func testReusableOtherSubscriber() throws {
        let otherSubscription = CustomSubscription()
        let otherPublisher = CustomPublisher(subscription: otherSubscription)
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(5),
            createSut: { $0.drop(untilOutputFrom: otherPublisher) }
        )

        let subscription2 = CustomSubscription()
        try XCTUnwrap(otherPublisher.subscriber).receive(subscription: subscription2)

        XCTAssertEqual(subscription2.history, [.cancelled])
        XCTAssertEqual(otherPublisher.send(1000), .none)

        let subscription3 = CustomSubscription()
        try XCTUnwrap(otherPublisher.subscriber).receive(subscription: subscription3)

        XCTAssertEqual(subscription3.history, [.requested(.max(1))])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(subscription3.history, [.requested(.max(1)),
                                               .cancelled])
        XCTAssertEqual(otherSubscription.history, [.requested(.max(1))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2)), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("DropUntilOutput")])
    }

    func testCrashesWhenReceivesInputAfterCancel() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.drop(untilOutputFrom: Empty<Void, TestingError>()) }
        )

        assertCrashes {
            _ = helper.publisher.send(0)
        }
    }

    func testDropUntilOutputReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 42,
            expected: .crash,
            { $0.drop(untilOutputFrom: Empty<Int, Never>()) }
        )
    }

    func testDropUntilOutputOtherReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 42,
            expected: .history([.subscription("DropUntilOutput"), .completion(.finished)],
                               demand: .none),
            { Empty<Int, Never>().drop(untilOutputFrom: $0) }
        )
    }

    func testDropUntilOutputReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("DropUntilOutput"),
                                .completion(.finished),
                                .completion(.finished)]),
            { $0.drop(untilOutputFrom: Empty<Int, Never>()) }
        )
    }

    func testDropUntilOutputOtherReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("DropUntilOutput"),
                                .completion(.finished),
                                .completion(.finished)]),
            { Empty<Int, Never>().drop(untilOutputFrom: $0) }
        )
    }

    func testDropUntilOutputRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.drop(untilOutputFrom: Empty<Int, Never>()) })
    }

    func testDropUntilOutputCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.cancelled]),
                                     { $0.drop(untilOutputFrom: Empty<Int, Never>()) })
    }

    func testDropUntilOutputReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice {
            $0.drop(untilOutputFrom: Empty<Int, TestingError>())
        }
    }

    func testDropUntilOutputLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.drop(untilOutputFrom: Empty<Int, TestingError>()) })
    }

    func testDropUntilOutputOtherLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { Empty<Int, TestingError>().drop(untilOutputFrom: $0) })
    }

    func testDropUntilOutputReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "DropUntilOutput",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "DropUntilOutput",
                           { $0.drop(untilOutputFrom: Empty<Int, TestingError>()) })

        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "DropUntilOutput",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "DropUntilOutput",
                           { Empty<Int, TestingError>().drop(untilOutputFrom: $0) })
    }
}
