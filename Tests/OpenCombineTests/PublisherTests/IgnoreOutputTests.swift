//
//  IgnoreOutputTests.swift
//
//  Created by Eric Patey on 16.08.20019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class IgnoreOutputTests: XCTestCase {

    func testCompletionWithEmpty() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let ignoreOutputPublisher = publisher.ignoreOutput()
        let tracking = TrackingSubscriberBase<Never, TestingError>(
            receiveSubscription: { $0.request(.max(42)) }
        )

        XCTAssertEqual(tracking.history, [])

        ignoreOutputPublisher.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        publisher.send(completion: .finished)
        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput"),
                                          .completion(.finished)])
    }

    func testCompletionWithValues() {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisher(subscription: upstreamSubscription)
        let ignoreOutputPublisher = upstreamPublisher.ignoreOutput()
        let tracking = TrackingSubscriberBase<Never, TestingError>(
            receiveSubscription: { $0.request(.max(42)) }
        )

        XCTAssertEqual(tracking.history, [])

        ignoreOutputPublisher.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        XCTAssertEqual(upstreamPublisher.send(666), .none)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        upstreamPublisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput"),
                                          .completion(.finished)])

        upstreamPublisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput"),
                                          .completion(.finished)])
    }

    func testCompletionWithError() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let ignoreOutputPublisher = publisher.ignoreOutput()
        let tracking = TrackingSubscriberBase<Never, TestingError>(
            receiveSubscription: { $0.request(.max(42)) }
        )

        XCTAssertEqual(tracking.history, [])

        ignoreOutputPublisher.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        XCTAssertEqual(publisher.send(666), .none)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput"),
                                          .completion(.failure(.oops))])
    }

    func testDemand() throws {
        // demand from downstream is ignored since no values are ever
        // sent. upstream demand is set to unlimited and left alone.
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(42),
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.ignoreOutput() })

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(95))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(50))
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])
    }

    func testSendsSubcriptionDownstreamBeforeDemandUpstream() {
        var didReceiveSubscription = false
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Error>(subscription: subscription)
        let ignoreOutput = publisher.ignoreOutput()
        let tracking = TrackingSubscriberBase<Never, Error>(
            receiveSubscription: { _ in
                XCTAssertEqual(subscription.history, [])
                didReceiveSubscription = true
            }
        )
        XCTAssertFalse(didReceiveSubscription)
        XCTAssertEqual(subscription.history, [])

        ignoreOutput.subscribe(tracking)

        XCTAssertTrue(didReceiveSubscription)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testReceiveSubscriptionTwice() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.ignoreOutput() }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled,
                                                     .cancelled])

        let thirdSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)

        XCTAssertEqual(thirdSubscription.history, [.cancelled])
    }

    func testIgnoreOutputReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.ignoreOutput() })
    }

    func testIgnoreOutputReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.ignoreOutput() }
        )
    }

    func testIgnoreOutputRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.ignoreOutput() })
    }

    func testIgnoreOutputCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     shouldCrash: false,
                                     { $0.ignoreOutput() })
    }

    func testIgnoreOutputLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.ignoreOutput() })
    }

    func testIgnoreOutputReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "IgnoreOutput",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("status", .contains("awaitingSubscription"))
                           ),
                           playgroundDescription: "IgnoreOutput",
                           { $0.ignoreOutput() })
    }
}
