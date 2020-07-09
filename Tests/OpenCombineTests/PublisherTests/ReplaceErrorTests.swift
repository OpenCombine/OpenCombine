//
//  ReplaceErrorTests.swift
//  OpenCombineTests
//
//  Created by Bogdan Vlad on 8/29/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ReplaceErrorTests: XCTestCase {

    func testEmpty() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceError(with: 42) })

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError")])
    }

    func testError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceError(with: 42) })

        helper.publisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .value(42),
                                                 .completion(.finished)
        ])
    }

    func testWithoutError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceError(with: 40) })

        XCTAssertEqual(helper.publisher.send(42), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .value(42),
                                                 .completion(.finished)])
    }

    func testSendingValueAndThenError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.replaceError(with: 42) })

        XCTAssertEqual(helper.publisher.send(41), .max(1))
        helper.publisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .value(41),
                                                 .value(42),
                                                 .completion(.finished)])
    }

    func testSendingErrorWithNoDemandThenFinish() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceError(with: 42) })

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .completion(.finished)])
    }

    func testFailingBeforeDemanding() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.replaceError(with: 42) })

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError")])

        helper.downstreamSubscription?.request(.unlimited)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .value(42),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(-1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .value(42),
                                                 .completion(.finished)])
    }

    func testReplaceErrorLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.replaceError(with: 10) })
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.replaceError(with: 42) })

        helper.downstreamSubscription?.cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        helper.downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testErrorWhileDownstreamDemandIsZero() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceError(with: 42) })

        // Send demanded value
        XCTAssertEqual(helper.publisher.send(9), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .value(9)])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .value(9)])

        helper.downstreamSubscription?.request(.max(1))
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .value(9),
                                                 .value(42),
                                                 .completion(.finished)])
    }

    func testCrashOnReceiveValueWithZeroPendingDemand() {
        let publisher = CustomPublisher(subscription: CustomSubscription())
        let replaceError = publisher.replaceError(with: 0)
        let tracking = TrackingSubscriberBase<Int, Never>()
        replaceError.subscribe(tracking)

        assertCrashes {
            XCTAssertEqual(publisher.send(1), .none)
        }
    }

    func testLateSubscription() throws {
        // This publisher doesn't send a subscription when it receives a subscriber
        let publisher = CustomPublisher(subscription: nil)
        let replaceError = publisher.replaceError(with: 1)
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(10)) }
        )

        replaceError.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("ReplaceError")])

        let subscription = CustomSubscription()
        publisher.send(subscription: subscription)

        XCTAssertEqual(subscription.history, [.requested(.max(10))])
        XCTAssertEqual(tracking.history, [.subscription("ReplaceError")])
    }

    func testReplaceErrorReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "ReplaceError",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "ReplaceError",
                           { $0.replaceError(with: 0) })
    }

    func testReceiveSubscriptionTwice() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceError(with: 42) })
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])

        let anotherSubscription = CustomSubscription()
        helper.publisher.subscriber?.receive(subscription: anotherSubscription)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(anotherSubscription.history, [.cancelled])

        helper.downstreamSubscription?.cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled])

        helper.publisher.subscriber?.receive(subscription: anotherSubscription)

        XCTAssertEqual(anotherSubscription.history, [.cancelled, .cancelled])
    }

    func testReceiveCompletionTwice() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceError(with: 42) })

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .completion(.finished)])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(-1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"),
                                                 .completion(.finished)])
    }

    func testReplaceErrorReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([.subscription("ReplaceError")], demand: .none),
            { $0.replaceError(with: 1) }
        )
    }

    func testReplaceErrorCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("ReplaceError")]),
            { $0.replaceError(with: 1) }
        )
    }

    func testReplaceErrorRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.replaceError(with: 0) })
    }

    func testReplaceErrorCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.replaceError(with: 0) })
    }
}
