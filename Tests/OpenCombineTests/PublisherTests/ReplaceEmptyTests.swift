//
//  ReplaceEmptyTests.swift
//  OpenCombine
//
//  Created by Joseph Spadafora on 12/10/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ReplaceEmptyTests: XCTestCase {
    func testEmptySubscription() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 15) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty")])
    }

    func testError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 42) }
        )

        helper.publisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .completion(.failure(.oops))])
    }

    func testEndWithoutValueReplacesCorrectly() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 42) }
        )

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(42),
                                                 .completion(.finished)])
    }

    func testNoValueIsReplacedIfEndsWithoutEmpty() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 42) }
        )

        XCTAssertEqual(helper.publisher.send(3), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(3),
                                                 .completion(.finished)])
    }

    func testSendingValueAndThenError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.replaceEmpty(with: 42) })

        XCTAssertEqual(helper.publisher.send(8), .max(1))
        helper.publisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(8),
                                                 .completion(.failure(.oops))])
    }

    func testFailingBeforeDemanding() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.replaceEmpty(with: 42) })

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty")])

        helper.publisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .completion(.failure(.oops))])

        helper.downstreamSubscription?.request(.unlimited)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .completion(.failure(.oops))])

        XCTAssertEqual(helper.publisher.send(-1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .completion(.failure(.oops))])
    }

    func testUpstreamCompletesEmptyBeforeDownstreamRequests() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 22) })
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty")])

        helper.subscription.request(.max(3))
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty")])

        helper.downstreamSubscription?.request(.max(1))
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(22),
                                                 .completion(.finished)])
    }

    // MARK: - Basic Behavior
    func testBasicBehavior() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 22) })
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(6), .none)
        XCTAssertEqual(helper.publisher.send(7), .none)
        XCTAssertEqual(helper.publisher.send(8), .none)
        XCTAssertEqual(helper.publisher.send(9), .none)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(10), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(2),
                                                 .value(4),
                                                 .value(6),
                                                 .value(7),
                                                 .value(8),
                                                 .value(9),
                                                 .completion(.finished)])
    }

    func testDemand() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(42),
                                        receiveValueDemand: .max(4),
                                        createSut: { $0.replaceEmpty(with: 832) })

        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(0), .max(4))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(2), .max(4))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(95))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5))])

        XCTAssertEqual(helper.publisher.send(3), .max(4))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5))])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(121))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .requested(.max(121))])

        XCTAssertEqual(helper.publisher.send(7), .max(4))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .requested(.max(121))])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .requested(.max(121)),
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(50))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .requested(.max(121)),
                                                     .cancelled])

        XCTAssertEqual(helper.publisher.send(8), .none)
    }

    func testImmediateCompletion() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 33) })
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.unlimited)])
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(33),
                                                 .completion(.finished)])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(33),
                                                 .completion(.finished)])
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: -7) })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.unlimited),
                                                     .cancelled])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.unlimited),
                                                     .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty")])
    }

    func testReceiveSubscriptionTwice() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.replaceEmpty(with: 22) }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled,
                                                     .cancelled])
    }

    func testReplaceEmptyReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "ReplaceEmpty",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "ReplaceEmpty",
                           { $0.replaceEmpty(with: 0) })
    }

    func testCrashesWhenRequestedZeroDemand() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.replaceEmpty(with: 9) }
        )

        assertCrashes {
            helper.downstreamSubscription?.request(.none)
        }
    }

    func testReplaceEmptyReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 213,
                                           expected: .history([], demand: .none)) {
            $0.replaceEmpty(with: 742)
        }
    }

    func testReplaceEmptyReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(inputType: Int.self,
                                                expected: .history([])) {
            $0.replaceEmpty(with: -14)
        }
    }

    func testReplaceEmptyRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.replaceEmpty(with: 19)
        }
    }

    func testReplaceEmptyCancelBeforeSubscription() {
        testCancelBeforeSubscription(
            inputType: Int.self,
            expected: .history([.requested(.unlimited)]),
            { $0.replaceEmpty(with: 1337) }
        )
    }

    func testReplaceEmptyLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: false,
                          { $0.replaceEmpty(with: 13) })
    }
}
