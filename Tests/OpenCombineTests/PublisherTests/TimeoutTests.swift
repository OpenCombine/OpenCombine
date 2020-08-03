//
//  TimeoutTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class TimeoutTests: XCTestCase {

    func testBasicBehaviorWithoutCustomError() {
        testBasicBehavior(customError: nil)
    }

    func testBasicBehaviorWithCustomError() {
        testBasicBehavior(customError: "timeout")
    }

    private func testBasicBehavior(customError: TestingError?) {

        let expectedCompletion =
            customError.map(Subscribers.Completion.failure) ?? .finished

        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(1),
            createSut: {
                $0.timeout(.nanoseconds(13),
                           scheduler: scheduler,
                           options: .nontrivialOptions,
                           customError: customError.map { e in { e } })
            }
        )
        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(10))
        XCTAssertEqual(helper.publisher.send(1), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])

        scheduler.rewind(to: .nanoseconds(11))
        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout"),
                                                 .value(1)])

        scheduler.rewind(to: .nanoseconds(12))

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout"),
                                                 .value(1),
                                                 .value(2)])

        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(23),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(24),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])

        scheduler.executeScheduledActions(until: .nanoseconds(200))

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout"),
                                                 .value(1),
                                                 .value(2),
                                                 .completion(expectedCompletion)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .cancelled])

        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(23),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(24),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(210))
        helper.publisher.send(completion: .finished)
        scheduler.rewind(to: .nanoseconds(220))
        helper.publisher.send(completion: .failure(.oops))

        scheduler.executeScheduledActions(until: .nanoseconds(400))

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout"),
                                                 .value(1),
                                                 .value(2),
                                                 .completion(expectedCompletion)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .cancelled])

        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(23),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(24),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])
    }

    func testNoUpstreamRequestOnZeroDemand() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: {
                $0.timeout(.nanoseconds(13),
                           scheduler: scheduler,
                           options: .nontrivialOptions)
            }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])

        XCTAssertEqual(helper.publisher.send(42), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])

        scheduler.rewind(to: .nanoseconds(2))

        // Since receiveValueDemand is .none,
        // no additional demand should be requested from upstream.

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
    }

    func testRequestWithoutCustomError() throws {
        try testRequest(customError: nil)
    }

    func testRequestWithCustomError() throws {
        try testRequest(customError: "timeout")
    }

    private func testRequest(customError: TestingError?) throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(1),
            createSut: {
                $0.timeout(.nanoseconds(13),
                           scheduler: scheduler,
                           options: .nontrivialOptions,
                           customError: customError.map { e in { e } })
            }
        )

        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        let downstreamSubscription = try XCTUnwrap(helper.downstreamSubscription)

        downstreamSubscription.request(.none)

        XCTAssertEqual(helper.subscription.history, [.requested(.none)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        downstreamSubscription.request(.max(2))
        downstreamSubscription.request(.max(42))

        XCTAssertEqual(helper.subscription.history, [.requested(.none),
                                                     .requested(.max(2)),
                                                     .requested(.max(42))])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(14))
        downstreamSubscription.request(.max(13))

        XCTAssertEqual(helper.subscription.history, [.requested(.none),
                                                     .requested(.max(2)),
                                                     .requested(.max(42)),
                                                     .cancelled])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])
    }

    func testCancellationWithoutCustomError() throws {
        try testCancellation(customError: nil)
    }

    func testCancellationWithCustomError() throws {
        try testCancellation(customError: "timeout")
    }

    private func testCancellation(customError: TestingError?) throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(1),
            createSut: {
                $0.timeout(.nanoseconds(13),
                           scheduler: scheduler,
                           options: .nontrivialOptions,
                           customError: customError.map { e in { e } })
            }
        )

        XCTAssertEqual(helper.subscription.history, [])
        let downstreamSubscription = try XCTUnwrap(helper.downstreamSubscription)

        downstreamSubscription.cancel()

        XCTAssertEqual(helper.subscription.history, [.cancelled])

        scheduler.rewind(to: .nanoseconds(14))

        XCTAssertEqual(helper.subscription.history, [.cancelled])
    }

    func testUpstreamFinishesCustomError() {
        testUpstreamCompletion(completion: .finished, customError: "timeout")
    }

    func testUpstreamFailsCustomError() {
        testUpstreamCompletion(completion: .failure(.oops), customError: "timeout")
    }

    func testUpstreamFinishesNoCustomError() {
        testUpstreamCompletion(completion: .finished, customError: nil)
    }

    func testUpstreamFailsNoCustomError() {
        testUpstreamCompletion(completion: .failure(.oops), customError: nil)
    }

    private func testUpstreamCompletion(completion: Subscribers.Completion<TestingError>,
                                        customError: TestingError?) {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(1),
            createSut: {
                $0.timeout(.nanoseconds(13),
                           scheduler: scheduler,
                           options: .nontrivialOptions,
                           customError: customError.map { e in { e } })
            }
        )

        helper.publisher.send(completion: completion)

        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])
        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])

        scheduler.rewind(to: .nanoseconds(2))

        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])
        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout"),
                                                 .completion(completion)])

        scheduler.rewind(to: .nanoseconds(20))

        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])
        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout"),
                                                 .completion(completion)])
    }

    func testCancelWhileInputIsInFlightWithCustomError() throws {
        try testCancelWhileInputIsInFlight(customError: "timeout")
    }

    func testCancelWhileInputIsInFlightWithoutCustomError() throws {
        try testCancelWhileInputIsInFlight(customError: nil)
    }

    private func testCancelWhileInputIsInFlight(customError: TestingError?) throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: {
                $0.timeout(.nanoseconds(13),
                           scheduler: scheduler,
                           options: .nontrivialOptions,
                           customError: customError.map { e in { e } })
            }
        )

        XCTAssertEqual(helper.publisher.send(42), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(200))

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])
    }

    func testCancelWhileFinishingIsInFlightWithCustomError() throws {
        try testCancelWhileCompletionIsInFlight(completion: .finished,
                                                customError: "timeout")
    }

    func testCancelWhileFailureIsInFlightWithCustomError() throws {
        try testCancelWhileCompletionIsInFlight(completion: .finished,
                                                customError: "timeout")
    }

    func testCancelWhileFinishingIsInFlightWithoutCustomError() throws {
        try testCancelWhileCompletionIsInFlight(completion: .failure(.oops),
                                                customError: nil)
    }

    func testCancelWhileFailureIsInFlightWithoutCustomError() throws {
        try testCancelWhileCompletionIsInFlight(completion: .failure(.oops),
                                                customError: nil)
    }

    private func testCancelWhileCompletionIsInFlight(
        completion: Subscribers.Completion<TestingError>,
        customError: TestingError?
    ) throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: {
                $0.timeout(.nanoseconds(13),
                           scheduler: scheduler,
                           options: .nontrivialOptions,
                           customError: customError.map { e in { e } })
            }
        )

        helper.publisher.send(completion: completion)

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(200))

        XCTAssertEqual(helper.tracking.history, [.subscription("Timeout")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: .nontrivialOptions)])
    }

    func testCrashesWithImmediateScheduler() {
        let publisher = CustomPublisher(subscription: CustomSubscription())
        let tracking = TrackingSubscriber()
        let timeout = publisher
            .timeout(.nanoseconds(10), scheduler: ImmediateScheduler.shared)

        assertCrashes {
            timeout.subscribe(tracking)
        }
    }

    func testTimeoutReceiveValueBeforeSubscription() {
        let scheduler = VirtualTimeScheduler()
        testReceiveValueBeforeSubscription(
            value: 42,
            expected: .history([], demand: .none),
            { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
        )
    }

    func testTimeoutReceiveCompletionBeforeSubscription() {
        let scheduler = VirtualTimeScheduler()
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
        )
    }

    func testTimeoutRequestBeforeSubscription() {
        let scheduler = VirtualTimeScheduler()
        testRequestBeforeSubscription(
            inputType: Int.self,
            shouldCrash: false,
            { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
        )
    }

    func testTimeoutReceiveSubscriptionTwice() throws {
        let scheduler = VirtualTimeScheduler()

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
        )

        XCTAssertEqual(helper.subscription.history, [])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.cancelled, .cancelled])
    }

    func testTimeoutCancelBeforeSubscription() {
        let scheduler = VirtualTimeScheduler()
        testCancelBeforeSubscription(
            inputType: Int.self,
            shouldCrash: false,
            { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
        )
    }

    func testSetupTimerStrongCapture() {
        let scheduler = VirtualTimeScheduler()
        var subscriptionDestroyed = false
        do {
            let helper = OperatorTestHelper(
                publisherType: CustomPublisher.self,
                initialDemand: nil,
                receiveValueDemand: .none,
                createSut: { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
            )

            helper.tracking.onDeinit = { subscriptionDestroyed = true }
        }

        XCTAssertFalse(subscriptionDestroyed)
    }

    func testReceiveValueScheduleStrongCapture() {
        let scheduler = VirtualTimeScheduler()
        var subscriptionDestroyed = false
        do {
            let helper = OperatorTestHelper(
                publisherType: CustomPublisher.self,
                initialDemand: nil,
                receiveValueDemand: .none,
                createSut: { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
            )

            helper.tracking.onDeinit = { subscriptionDestroyed = true }

            XCTAssertEqual(helper.publisher.send(1), .none)
        }

        XCTAssertFalse(subscriptionDestroyed)
    }

    func testReceiveCompletionScheduleStrongCapture() {
        let scheduler = VirtualTimeScheduler()
        var subscriptionDestroyed = false
        do {
            let helper = OperatorTestHelper(
                publisherType: CustomPublisher.self,
                initialDemand: nil,
                receiveValueDemand: .none,
                createSut: { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
            )

            helper.tracking.onDeinit = { subscriptionDestroyed = true }

            helper.publisher.send(completion: .finished)
        }

        XCTAssertFalse(subscriptionDestroyed)
    }

    func testTimeoutReflection() throws {
        try testReflection(
            parentInput: Double.self,
            parentFailure: Error.self,
            description: "Timeout",
            customMirror: childrenIsEmpty,
            playgroundDescription: "Timeout",
            { $0.timeout(.nanoseconds(13), scheduler: VirtualTimeScheduler()) }
        )
    }
}
