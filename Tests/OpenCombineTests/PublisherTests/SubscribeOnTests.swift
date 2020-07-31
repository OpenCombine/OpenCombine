//
//  SubscribeOnTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class SubscribeOnTests: XCTestCase {

    func testSynchronouslySendsEventsDownstream() throws {
        let scheduler = VirtualTimeScheduler()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let subscribeOn = publisher.subscribe(on: scheduler, options: .nontrivialOptions)
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(100)) },
            receiveValue: { _ in .max(12) }
        )

        publisher.didSubscribe = { _ in
            XCTAssertEqual(tracking.history,
                           [.subscription("SubscribeOn")],
                           "Subscription object should be sent synchronously")
            XCTAssertEqual(subscription.history,
                           [],
                           "Demand should be requested asynchronously")
        }

        subscribeOn.subscribe(tracking)

        XCTAssertNil(publisher.subscriber,
                     "Subscription must be performed asynchronously")

        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: .nontrivialOptions)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(subscription.history, [.requested(.max(100))])

        XCTAssertEqual(publisher.send(1), .max(12))
        XCTAssertEqual(publisher.send(2), .max(12))
        XCTAssertEqual(publisher.send(3), .max(12))

        XCTAssertEqual(tracking.history, [.subscription("SubscribeOn"),
                                          .value(1),
                                          .value(2),
                                          .value(3)])
        XCTAssertEqual(subscription.history, [.requested(.max(100))])
        XCTAssertEqual(scheduler.history, [.schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions)])

        publisher.send(completion: .finished)
        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(publisher.send(-1), .none)

        XCTAssertEqual(tracking.history, [.subscription("SubscribeOn"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .completion(.finished)])
        XCTAssertEqual(subscription.history, [.requested(.max(100))])
        XCTAssertEqual(scheduler.history, [.schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions)])
    }

    func testAsynchronouslySendsEventsUpstream() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .unlimited) {
            $0.subscribe(on: scheduler, options: .nontrivialOptions)
        }
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: .nontrivialOptions)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(17))
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).request(.none)

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(17)),
                                                     .requested(.unlimited),
                                                     .requested(.none)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(17)),
                                                     .requested(.unlimited),
                                                     .requested(.none)])
        XCTAssertEqual(scheduler.history, [.schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions),
                                           .schedule(options: .nontrivialOptions)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(17)),
                                                     .requested(.unlimited),
                                                     .requested(.none),
                                                     .cancelled])
    }

    func testCancelAlreadyCancelled() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(42)) {
            $0.subscribe(on: scheduler)
        }
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send(1000), .none)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                           .schedule(options: nil)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [.cancelled])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                           .schedule(options: nil)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(20000))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                           .schedule(options: nil)])

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [.cancelled])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                           .schedule(options: nil)])
    }

    func testCancelImmediatelyAfterRequest() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(42)) {
            $0.subscribe(on: scheduler)
        }
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil)])

        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                           .schedule(options: nil),
                                           .schedule(options: nil)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("SubscribeOn")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                           .schedule(options: nil),
                                           .schedule(options: nil)])
    }

    func testCrashWhenRequestingRecursively() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none) {
            $0.subscribe(on: ImmediateScheduler.shared)
        }

        var recursionCounter = 5
        helper.subscription.onRequest = { _ in
            if recursionCounter == 0 { return }
            recursionCounter -= 1
            helper.downstreamSubscription?.request(.unlimited)
        }

        try assertCrashes {
            try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        }
    }

    func testCancelRecursively() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none) {
            $0.subscribe(on: ImmediateScheduler.shared)
        }

        helper.subscription.onCancel = {
            helper.downstreamSubscription?.cancel()
        }

        try XCTUnwrap(helper.downstreamSubscription).cancel()
    }

    func testStrongCaptureWhenSchedulingRequest() throws {
        let scheduler = VirtualTimeScheduler()
        var subscriberReleased = false
        let subscription = CustomSubscription()
        do {
            let publisher = CustomPublisher(subscription: subscription)
            let subscribeOn = publisher.subscribe(on: scheduler)
            var downstreamSubscription: Subscription?
            let tracking = TrackingSubscriber(
                receiveSubscription: { downstreamSubscription = $0 },
                onDeinit: { subscriberReleased = true }
            )
            subscribeOn.subscribe(tracking)
            scheduler.executeScheduledActions()
            try XCTUnwrap(downstreamSubscription).request(.max(1))
            XCTAssertEqual(subscription.history, [])
            XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                               .schedule(options: nil)])
            publisher.cancel()
            tracking.cancel()
        }
        XCTAssertFalse(subscriberReleased)
        scheduler.executeScheduledActions()
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .cancelled])
    }

    func testStrongCaptureWhenSchedulingCancel() throws {
        let scheduler = VirtualTimeScheduler()
        var subscriberReleased = false
        let subscription = CustomSubscription()
        do {
            let publisher = CustomPublisher(subscription: subscription)
            let subscribeOn = publisher.subscribe(on: scheduler)
            var downstreamSubscription: Subscription?
            let tracking = TrackingSubscriber(
                receiveSubscription: { downstreamSubscription = $0 },
                onDeinit: { subscriberReleased = true }
            )
            subscribeOn.subscribe(tracking)
            scheduler.executeScheduledActions()
            try XCTUnwrap(downstreamSubscription).cancel()
            XCTAssertEqual(subscription.history, [])
            XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                               .schedule(options: nil)])
            publisher.cancel()
            tracking.cancel()
        }
        XCTAssertFalse(subscriberReleased)
        scheduler.executeScheduledActions()
        XCTAssertEqual(subscription.history, [.cancelled])
    }

    func testSubscribeOnReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice {
            $0.subscribe(on: ImmediateScheduler.shared)
        }
    }

    func testSubscribeOnReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 213,
                                           expected: .history([], demand: .none)) {
            $0.subscribe(on: ImmediateScheduler.shared)
        }
    }

    func testSubscribeOnReceiveCompletionBeforeSubscription()  {
        testReceiveCompletionBeforeSubscription(inputType: Int.self,
                                                expected: .history([])) {
            $0.subscribe(on: ImmediateScheduler.shared)
        }
    }

    func testSubscribeOnRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.subscribe(on: ImmediateScheduler.shared)
        }
    }

    func testSubscribeOnCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.subscribe(on: ImmediateScheduler.shared)
        }
    }

    func testSubscribeOnReflection() throws {
        try testReflection(parentInput: Double.self,
                           parentFailure: Error.self,
                           description: "SubscribeOn",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "SubscribeOn",
                           { $0.subscribe(on: ImmediateScheduler.shared) })
    }

    func testSubscribeOnLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false) {
            $0.subscribe(on: ImmediateScheduler.shared)
        }
    }
}
