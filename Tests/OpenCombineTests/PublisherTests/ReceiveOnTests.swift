//
//  ReceiveOnTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ReceiveOnTests: XCTestCase {

    func testBasicBehavior() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(100),
                                        receiveValueDemand: .max(12)) {
            $0.receive(on: scheduler, options: .init(481516))
        }
        XCTAssertNotNil(helper.publisher.subscriber)

        XCTAssertEqual(helper.tracking.history, [])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: .init(481516))])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100))])
        XCTAssertEqual(scheduler.history, [.schedule(options: .init(481516))])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100))])
        XCTAssertEqual(scheduler.scheduledDates, [.init(nanoseconds: 0),
                                                  .init(nanoseconds: 0),
                                                  .init(nanoseconds: 0)])

        XCTAssertEqual(scheduler.history, [.schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516))])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn"),
                                                 .value(1),
                                                 .value(3),
                                                 .value(2)])

        XCTAssertEqual(helper.subscription.history, [.requested(.max(100)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12))])

        XCTAssertEqual(scheduler.history, [.schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516))])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(4), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn"),
                                                 .value(1),
                                                 .value(3),
                                                 .value(2)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12))])
        XCTAssertEqual(scheduler.scheduledDates, [.init(nanoseconds: 0)])
        XCTAssertEqual(scheduler.history, [.schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516))])
        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn"),
                                                 .value(1),
                                                 .value(3),
                                                 .value(2),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(100)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12)),
                                                     .requested(.max(12))])
        XCTAssertEqual(scheduler.history, [.schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516)),
                                           .schedule(options: .init(481516))])
        XCTAssertEqual(scheduler.now, .init(nanoseconds: 0))
    }

    func testRequest() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none) {
            $0.receive(on: scheduler)
        }
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn")])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(10))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(4))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))
        try XCTUnwrap(helper.downstreamSubscription).request(.none)
        XCTAssertEqual(helper.publisher.send(2000), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(10)),
                                                     .requested(.max(4)),
                                                     .requested(.max(5)),
                                                     .requested(.none)])

        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn"),
                                                 .value(2000)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(10)),
                                                     .requested(.max(4)),
                                                     .requested(.max(5)),
                                                     .requested(.none)])
    }

    func testCancelAlreadyCancelled() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.receive(on: scheduler)
        }

        scheduler.executeScheduledActions()
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn")])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(42))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn")])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil)])

        XCTAssertEqual(helper.publisher.send(0), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn")])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil)])
    }

    func testReceiveCompletionImmediatelyAfterSubscription() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.receive(on: scheduler)
        }

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                           .schedule(options: nil)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [])
    }

    func testReceiveCompletionImmediatelyAfterValue() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.receive(on: scheduler)
        }
        XCTAssertEqual(helper.publisher.send(-1), .none)
        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.publisher.send(1000), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn"),
                                                 .value(-1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.max(418))])
        XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                           .schedule(options: nil),
                                           .schedule(options: nil),
                                           .schedule(options: nil)])

        scheduler.executeScheduledActions()

        XCTAssertEqual(helper.tracking.history, [.subscription("ReceiveOn"),
                                                 .value(-1),
                                                 .value(1000),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.max(418))])
    }

    func testCrashesWhenReceivingInputRecursively() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.receive(on: ImmediateScheduler.shared)
        }

        helper.tracking.onValue = { _ in
            _ = helper.publisher.send(-1)
        }

        assertCrashes {
            _ = helper.publisher.send(0)
        }
    }

    func testReceiveCompletionRecursively() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(418)) {
            $0.receive(on: ImmediateScheduler.shared)
        }
        helper.tracking.onFinish = {
            helper.publisher.send(completion: .finished)
        }
        helper.publisher.send(completion: .finished)
    }

    func testWeakCaptureWhenSchedulingSubscription() {
        let scheduler = VirtualTimeScheduler()
        var subscription: Subscription?
        var subscriberReleased = false
        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let delay = publisher.receive(on: scheduler)
            let tracking = TrackingSubscriber(receiveSubscription: { subscription = $0 },
                                              onDeinit: { subscriberReleased = true })
            delay.subscribe(tracking)
            XCTAssertEqual(tracking.history, [])
            XCTAssertEqual(scheduler.history, [.schedule(options: nil)])
            publisher.cancel()
        }
        scheduler.executeScheduledActions()
        XCTAssertNil(subscription)
        XCTAssertTrue(subscriberReleased)
    }

    func testWeakCaptureWhenSchedulingValue() {
        let scheduler = VirtualTimeScheduler()
        var value: Int?
        var subscriberReleased = false
        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let delay = publisher.receive(on: scheduler)
            let tracking = TrackingSubscriber(receiveValue: { value = $0; return .none },
                                              onDeinit: { subscriberReleased = true })
            delay.subscribe(tracking)
            scheduler.executeScheduledActions()
            XCTAssertEqual(tracking.history, [.subscription("ReceiveOn")])
            XCTAssertEqual(publisher.send(42), .none)
            XCTAssertEqual(tracking.history, [.subscription("ReceiveOn")])
            XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                               .schedule(options: nil)])
            tracking.cancel()
            publisher.cancel()
        }
        scheduler.executeScheduledActions()
        XCTAssertNil(value)
        XCTAssertTrue(subscriberReleased)
    }

    func testWeakCaptureWhenSchedulingCompletion() {
        let scheduler = VirtualTimeScheduler()
        var completion: Subscribers.Completion<TestingError>?
        var subscriberReleased = false
        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let delay = publisher.receive(on: scheduler)
            let tracking = TrackingSubscriber(receiveCompletion: { completion = $0 },
                                              onDeinit: { subscriberReleased = true })
            delay.subscribe(tracking)
            scheduler.executeScheduledActions()
            XCTAssertEqual(tracking.history, [.subscription("ReceiveOn")])
            publisher.send(completion: .finished)
            XCTAssertEqual(tracking.history, [.subscription("ReceiveOn")])
            XCTAssertEqual(scheduler.history, [.schedule(options: nil),
                                               .schedule(options: nil)])
            tracking.cancel()
            publisher.cancel()
        }
        scheduler.executeScheduledActions()
        XCTAssertNil(completion)
        XCTAssertTrue(subscriberReleased)
    }

    func testReceiveOnReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice {
            $0.receive(on: ImmediateScheduler.shared)
        }
    }

    func testReceiveOnReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 213,
                                           expected: .history([], demand: .none)) {
            $0.receive(on: ImmediateScheduler.shared)
        }
    }

    func testReceiveOnReceiveCompletionBeforeSubscription()  {
        testReceiveCompletionBeforeSubscription(inputType: Int.self,
                                                expected: .history([])) {
            $0.receive(on: ImmediateScheduler.shared)
        }
    }

    func testReceiveOnRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.receive(on: ImmediateScheduler.shared)
        }
    }

    func testReceiveOnCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.receive(on: ImmediateScheduler.shared)
        }
    }

    func testReceiveOnReflection() throws {
        try testReflection(parentInput: String.self,
                           parentFailure: Error.self,
                           description: "ReceiveOn",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "ReceiveOn",
                           { $0.receive(on: ImmediateScheduler.shared) })
    }

    func testReceiveOnLifecycle() throws {
        try testLifecycle(sendValue: 31, cancellingSubscriptionReleasesSubscriber: true) {
            $0.receive(on: ImmediateScheduler.shared)
        }
    }
}
