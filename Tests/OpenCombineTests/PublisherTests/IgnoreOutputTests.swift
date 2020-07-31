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
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])

        publisher.send(completion: .finished)
        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .completion(.finished),
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
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])

        XCTAssertEqual(upstreamPublisher.send(666), .none)
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])

        upstreamPublisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .completion(.finished)])

        upstreamPublisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .completion(.finished),
                                          .completion(.failure(.oops))])
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
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])

        XCTAssertEqual(publisher.send(666), .none)
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])

        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .completion(.failure(.oops)),
                                          .completion(.failure(.oops)),
                                          .completion(.finished)])
    }

    func testDemand() throws {
        // demand from downstream is ignored since no values are ever
        // sent. upstream demand is set to unlimited and left alone.
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(42),
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.ignoreOutput() })

        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(95))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5))])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .cancelled,
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(50))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.unlimited),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .cancelled,
                                                     .cancelled,
                                                     .requested(.max(50))])
    }

    func testSendsSubscriptionDownstreamBeforeDemandUpstream() {
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

        XCTAssertEqual(secondSubscription.history, [.requested(.unlimited)])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.unlimited),
                                                     .cancelled])

        let thirdSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)

        XCTAssertEqual(thirdSubscription.history, [.requested(.unlimited)])
    }

    func testIgnoreOutputReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.ignoreOutput() })
    }

    func testIgnoreOutputReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.ignoreOutput() }
        )
    }

    func testIgnoreOutputLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: true,
                          { $0.ignoreOutput() })
    }

    func testIgnoreOutputReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "IgnoreOutput",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "IgnoreOutput",
                           subscriberIsAlsoSubscription: false,
                           { $0.ignoreOutput() })
    }
}
