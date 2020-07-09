//
//  RetryTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.07.2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class RetryTests: XCTestCase {

    func testRetry3Times() throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let retry = publisher.retry(3)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                downstreamSubscription = $0
                $0.request(.max(5))
            }
        )
        var upstreamSubscribeCounter = 0
        publisher.didSubscribe = { _, _ in
            if upstreamSubscribeCounter == 0 {
                XCTAssertEqual(tracking.history, [.subscription("Retry")])
            }
            upstreamSubscribeCounter += 1
        }

        retry.subscribe(tracking)

        XCTAssertEqual(upstreamSubscribeCounter, 1)

        XCTAssertEqual(publisher.send(1), .none)
        publisher.send(completion: .failure("oops1"))

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .value(1)])
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(4))])
        XCTAssertEqual(upstreamSubscribeCounter, 2)

        XCTAssertEqual(publisher.send(2), .none)
        publisher.send(completion: .failure("oops2"))

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .value(1),
                                          .value(2)])
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(4)),
                                              .requested(.max(3))])
        XCTAssertEqual(upstreamSubscribeCounter, 3)

        XCTAssertEqual(publisher.send(3), .none)
        publisher.send(completion: .failure("oops3"))

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .value(1),
                                          .value(2),
                                          .value(3)])
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(4)),
                                              .requested(.max(3)),
                                              .requested(.max(2))])
        XCTAssertEqual(upstreamSubscribeCounter, 4)

        XCTAssertEqual(publisher.send(4), .none)
        publisher.send(completion: .failure("oops4"))

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .completion(.failure("oops4"))])
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(4)),
                                              .requested(.max(3)),
                                              .requested(.max(2))])
        XCTAssertEqual(upstreamSubscribeCounter, 4)

        XCTAssertEqual(publisher.send(5), .none)
        publisher.send(completion: .failure("oops5"))

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .completion(.failure("oops4"))])
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(4)),
                                              .requested(.max(3)),
                                              .requested(.max(2))])
        XCTAssertEqual(upstreamSubscribeCounter, 4)

        try XCTUnwrap(downstreamSubscription).request(.max(112))
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(4)),
                                              .requested(.max(3)),
                                              .requested(.max(2))])
    }

    func testRetry0Times() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: { $0.retry(0) }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("Retry"),
                                                 .value(1),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])

        XCTAssertEqual(helper.publisher.send(2), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("Retry"),
                                                 .value(1),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
    }

    func testRetryForever() {
        testRetryForever(attempts: nil)
    }

    func testRetryNegativeAmountOfTimes() {
        testRetryForever(attempts: -1)
    }

    func testFinishSuccessfullyFirstTime() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .none,
            createSut: { $0.retry(3) }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("Retry"),
                                                 .value(1),
                                                 .value(2),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
    }

    func testFinishSuccessfullyAfterRetry() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(4),
            receiveValueDemand: .none,
            createSut: { $0.retry(3) }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("Retry"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(4)),
                                                     .requested(.max(2))])
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.retry(3) })

        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(helper.tracking.history, [.subscription("Retry")])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(3))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.publisher.send(42), .none)

        XCTAssertEqual(helper.subscription.history, [.cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("Retry")])
    }

    func testPreservesDemand() {
        let publisher = CustomPublisher(subscription: nil)
        let retry = publisher.retry(5)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(3)) },
                                          receiveValue: { .max($0) })
        retry.subscribe(tracking)

        XCTAssertEqual(tracking.history, [])

        let subscription = CustomSubscription()
        publisher.send(subscription: subscription)

        XCTAssertEqual(subscription.history, [.requested(.max(3))])
        XCTAssertEqual(publisher.send(5), .none)

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .value(5)])
        XCTAssertEqual(subscription.history, [.requested(.max(3)),
                                              .requested(.max(5))])
    }

    func testCrashesOnUnwantedValue() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.retry(2) }
        )

        assertCrashes {
            _ = helper.publisher.send(-1)
        }
    }

    func testSubscriptionRecursion() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let retry = publisher.retry(5)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(1)) })
        var upstreamSubscribeCounter = 0
        publisher.didSubscribe = { _, _ in
            if upstreamSubscribeCounter > 0 && upstreamSubscribeCounter < 10 {
                publisher.send(completion: .failure(.oops))
            }
            upstreamSubscribeCounter += 1
        }

        retry.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Retry")])
        XCTAssertEqual(subscription.history, [.requested(.max(1))])
        XCTAssertEqual(upstreamSubscribeCounter, 1)

        publisher.send(completion: .failure(.oops))

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .completion(.failure(.oops))])
        XCTAssertEqual(subscription.history,
                       Array(repeating: .requested(.max(1)), count: 6))
        XCTAssertEqual(upstreamSubscribeCounter, 6)
    }

    func testRecurseAndFinish() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let retry = publisher.retry(5)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(1)) })
        var upstreamSubscribeCounter = 0
        publisher.didSubscribe = { _, _ in
            if upstreamSubscribeCounter > 0 {
                if upstreamSubscribeCounter < 5 {
                    publisher.send(completion: .failure(.oops))
                } else {
                    publisher.send(completion: .finished)
                }
            }
            upstreamSubscribeCounter += 1
        }

        retry.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Retry")])
        XCTAssertEqual(subscription.history, [.requested(.max(1))])
        XCTAssertEqual(upstreamSubscribeCounter, 1)

        publisher.send(completion: .failure(.oops))

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .completion(.finished)])
        XCTAssertEqual(subscription.history,
                       Array(repeating: .requested(.max(1)), count: 6))
        XCTAssertEqual(upstreamSubscribeCounter, 6)
    }

    func testRecurseAndReceiveValue() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let retry = publisher.retry(1)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(3)) },
                                          receiveValue: { _ in .max(2) })
        var upstreamSubscribeCounter = 0
        publisher.willSubscribe = { _, _ in
            if upstreamSubscribeCounter > 0 {
                XCTAssertEqual(publisher.send(1), .none)
            }
            upstreamSubscribeCounter += 1
        }

        retry.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Retry")])
        XCTAssertEqual(subscription.history, [.requested(.max(3))])
        XCTAssertEqual(upstreamSubscribeCounter, 1)

        publisher.send(completion: .failure(.oops))

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .value(1)])
        XCTAssertEqual(subscription.history, [.requested(.max(3)),
                                              .requested(.max(4))])
        XCTAssertEqual(upstreamSubscribeCounter, 2)
    }

    func testRetryReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 31,
            expected: .crash,
            { $0.retry(3) }
        )
    }

    func testRetryReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.retry(3) }
        )
    }

    func testRetryRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.retry(3) })
    }

    func testRetryCancelBeforeSubscription() {
        testCancelBeforeSubscription(
            inputType: Int.self,
            expected: .history([.cancelled]),
            { $0.retry(3) }
        )
    }

    func testRetryReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.retry(3) }
    }

    func testRetryLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: true,
                          { $0.retry(3) })
    }

    func testRetryReflection() throws {
        try testReflection(
            parentInput: Int.self,
            parentFailure: TestingError.self,
            description: "Retry",
            customMirror: childrenIsEmpty,
            playgroundDescription: "Retry",
            { $0.retry(3) }
        )
    }

    // MARK: - Private

    private func testRetryForever(attempts: Int?) {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let retry = Publishers.Retry(upstream: publisher, retries: attempts)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(1)) })
        var upstreamSubscribeCounter = 0
        publisher.didSubscribe = { _, _ in
            upstreamSubscribeCounter += 1
        }

        retry.subscribe(tracking)

        XCTAssertEqual(upstreamSubscribeCounter, 1)

        for _ in 0 ..< 10000 {
            publisher.send(completion: .failure(.oops))
        }

        XCTAssertEqual(publisher.send(0), .none)

        XCTAssertEqual(tracking.history, [.subscription("Retry"),
                                          .value(0)])
        XCTAssertEqual(subscription.history,
                       Array(repeating: .requested(.max(1)), count: 10001))
        XCTAssertEqual(upstreamSubscribeCounter, 10001)
    }
}
