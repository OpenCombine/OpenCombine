//
//  PrefixUntilOutputTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.11.2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class PrefixUntilOutputTests: XCTestCase {

    func testBasicBehavior() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(2),
            createSut: { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )

        XCTAssertEqual(helper.tracking.history,
                       [.subscription(.contains("PrefixUntilOutput"))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])

        XCTAssertEqual(helper.publisher.send(1), .max(2))
        XCTAssertEqual(helper.publisher.send(2), .max(2))

        XCTAssertEqual(terminatingPublisher.send(1000), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription(.contains("PrefixUntilOutput")),
                        .value(1),
                        .value(2),
                        .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(terminatingPublisher.send(1001), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription(.contains("PrefixUntilOutput")),
                        .value(1),
                        .value(2),
                        .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history,
                       [.subscription(.contains("PrefixUntilOutput")),
                        .value(1),
                        .value(2),
                        .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])
    }

    func testCombineIdentifiers() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(2),
            createSut: { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )

        XCTAssertEqual(terminatingPublisher.subscriber?.combineIdentifier,
                       helper.publisher.subscriber?.combineIdentifier)
    }

    func testRequestZeroDemand() throws {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(2),
            createSut: { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )

        try XCTUnwrap(helper.downstreamSubscription).request(.none)

        XCTAssertEqual(helper.subscription.history, [.requested(.none)])
    }

    func testCancellation() throws {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(2),
            createSut: { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )

        terminatingSubscription.onCancel = {
            XCTAssertEqual(helper.subscription.history,
                           [.cancelled],
                           "Upstream subscription should be cancelled first")
        }

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.cancelled])
        XCTAssertEqual(terminatingSubscription.history,
                       [.requested(.max(1)), .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(42))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.cancelled])
        XCTAssertEqual(terminatingSubscription.history,
                       [.requested(.max(1)), .cancelled])
    }

    func testUpstreamCompletion() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(2),
            createSut: { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )

        helper.tracking.onFinish = {
            XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1)),
                                                             .cancelled])
        }

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription(.contains("PrefixUntilOutput")),
                        .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1)),
                                                         .cancelled])
    }

    func testCancelsUpstreamWhenTerminatorSendsValue() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(2),
            createSut: { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )

        helper.tracking.onFinish = {
            XCTAssertEqual(helper.subscription.history, [.cancelled])
        }

        XCTAssertEqual(terminatingPublisher.send(42), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription(.contains("PrefixUntilOutput")),
                        .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.cancelled])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])
    }

    func testTerminatorFinishesWithoutProducingValues() {
        testTerminatorCompletesWithoutProducingValues(completion: .finished)
    }

    func testTerminatorFailsWithoutProducingValues() {
        testTerminatorCompletesWithoutProducingValues(completion: .failure(.oops))
    }

    private func testTerminatorCompletesWithoutProducingValues(
        completion: Subscribers.Completion<TestingError>
    ) {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(2),
            createSut: { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )

        terminatingPublisher.send(completion: completion)

        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(helper.tracking.history,
                       [.subscription(.contains("PrefixUntilOutput"))])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])

        XCTAssertEqual(terminatingPublisher.send(42), .none)
        terminatingPublisher.send(completion: .finished)
        terminatingPublisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(1), .max(2))

        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(helper.tracking.history,
                       [.subscription(.contains("PrefixUntilOutput")), .value(1)])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])
    }

    func testTerminatorEmitsValueBeforeUpstreamSendsSubscription() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)

        let upstream = CustomPublisher(subscription: nil)
        let tracking = TrackingSubscriber()
        upstream.prefix(untilOutputFrom: terminatingPublisher).subscribe(tracking)

        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])

        XCTAssertEqual(terminatingPublisher.send(-1), .none)

        XCTAssertEqual(tracking.history, [.completion(.finished)])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])

        let subscription = CustomSubscription()
        upstream.send(subscription: subscription)

        XCTAssertEqual(subscription.history, [.cancelled])
        XCTAssertEqual(tracking.history, [.completion(.finished)])
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])
    }

    func testPrefixUntilOutputReceiveValueBeforeSubscription() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)
        testReceiveValueBeforeSubscription(
            value: 31,
            expected: .history([], demand: .none),
            { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        testReceiveValueBeforeSubscription(
            value: 31,
            expected: .history([.subscription(.contains("PrefixUntilOutput"))],
                               demand: .none),
            { publisher.prefix(untilOutputFrom: $0) }
        )
        XCTAssertEqual(subscription.history, [])
    }

    func testPrefixUntilOutputReceiveCompletionBeforeSubscription() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1)), .cancelled])

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription(.contains("PrefixUntilOutput"))]),
            { publisher.prefix(untilOutputFrom: $0) }
        )
        XCTAssertEqual(subscription.history, [])
    }

    func testPrefixUntilOutputRequestBeforeSubscription() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)
        testRequestBeforeSubscription(
            inputType: Int.self,
            shouldCrash: false,
            { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1))])
    }

    func testPrefixUntilOutputCancelBeforeSubscription() {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)
        testCancelBeforeSubscription(
            inputType: Int.self,
            expected: .history([.cancelled]),
            { $0.prefix(untilOutputFrom: terminatingPublisher) }
        )

        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1)), .cancelled])
    }

    func testPrefixUntilOutputReceiveSubscriptionTwice() throws {
        let terminatingSubscription = CustomSubscription()
        let terminatingPublisher = CustomPublisher(subscription: terminatingSubscription)
        try testReceiveSubscriptionTwice {
            $0.prefix(untilOutputFrom: terminatingPublisher)
        }
        XCTAssertEqual(terminatingSubscription.history, [.requested(.max(1)), .cancelled])

        do {
            let subscription = CustomSubscription()
            let publisher = CustomPublisher(subscription: subscription)
            let helper = OperatorTestHelper(
                publisherType: CustomPublisher.self,
                initialDemand: nil,
                receiveValueDemand: .none,
                createSut: { publisher.prefix(untilOutputFrom: $0) }
            )

            XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])

            let secondSubscription = CustomSubscription()

            try XCTUnwrap(helper.publisher.subscriber)
                .receive(subscription: secondSubscription)

            XCTAssertEqual(secondSubscription.history, [.cancelled])

            try XCTUnwrap(helper.publisher.subscriber)
                .receive(subscription: helper.subscription)

            XCTAssertEqual(helper.subscription.history, [.requested(.max(1)),
                                                         .cancelled])

            try XCTUnwrap(helper.downstreamSubscription).cancel()

            XCTAssertEqual(helper.subscription.history, [.requested(.max(1)),
                                                         .cancelled,
                                                         .cancelled])
            XCTAssertEqual(subscription.history, [.cancelled])
        }
    }

    func testPrefixUntilOutputReflection() throws {
        // PrefixUntilOutput's Inner doesn't customize its reflection
        let terminatingPublisher = CustomPublisher(subscription: CustomSubscription())
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: nil,
                           customMirror: nil,
                           playgroundDescription: nil) {
            $0.prefix(untilOutputFrom: terminatingPublisher)
        }

        let publisher = CustomPublisher(subscription: CustomSubscription())
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: nil,
                           customMirror: nil,
                           playgroundDescription: nil) {
            publisher.prefix(untilOutputFrom: $0)
        }
    }

    func testPrefixUntilOutputLifecycle() throws {
        let terminatingPublisher = CustomPublisher(subscription: CustomSubscription())
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: false,
                          { $0.prefix(untilOutputFrom: terminatingPublisher) })

        let publisher = CustomPublisher(subscription: CustomSubscription())
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: false,
                          { publisher.prefix(untilOutputFrom: $0) })
    }
}
