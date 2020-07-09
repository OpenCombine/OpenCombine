//
//  DebounceTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 28.06.2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class DebounceTests: XCTestCase {

    func testBasicBehavior() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(1),
            createSut: {
                $0.debounce(for: .nanoseconds(13),
                            scheduler: scheduler,
                            options: .nontrivialOptions)
            }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [])

        XCTAssertEqual(helper.publisher.send(1), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(4))
        XCTAssertEqual(helper.publisher.send(2), .none)
        scheduler.rewind(to: .nanoseconds(9))
        XCTAssertEqual(helper.publisher.send(3), .none)

        scheduler.rewind(to: .nanoseconds(200))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .value(3)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(17),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(22),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops)) // ignored
        XCTAssertEqual(helper.publisher.send(-1), .none) // ignored

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .value(3)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(17),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(22),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: nil)])

        scheduler.rewind(to: .nanoseconds(300))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .value(3),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(17),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(22),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: nil)])
        XCTAssertEqual(scheduler.cancellableTokenDeinitCount, 3)
    }

    func testFinishBeforeDue() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: {
                $0.debounce(for: .nanoseconds(13),
                            scheduler: scheduler,
                            options: .nontrivialOptions)
            }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        scheduler.rewind(to: .nanoseconds(4))
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: nil)])

        scheduler.rewind(to: .nanoseconds(100))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: nil)])
        XCTAssertEqual(scheduler.cancellableTokenDeinitCount, 1)
    }

    func testFailBeforeDue() {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: {
                $0.debounce(for: .nanoseconds(13),
                            scheduler: scheduler,
                            options: .nontrivialOptions)
            }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        scheduler.rewind(to: .nanoseconds(4))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: nil)])

        scheduler.rewind(to: .nanoseconds(100))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .schedule(options: nil)])
        XCTAssertEqual(scheduler.cancellableTokenDeinitCount, 1)
    }

    func testCancelBeforeDue() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: {
                $0.debounce(for: .nanoseconds(13),
                            scheduler: scheduler,
                            options: .nontrivialOptions)
            }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        scheduler.rewind(to: .nanoseconds(4))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(100))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])
        XCTAssertEqual(scheduler.cancellableTokenDeinitCount, 1)
    }

    func testDemand() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: {
                $0.debounce(for: .nanoseconds(13),
                            scheduler: scheduler,
                            options: .nontrivialOptions)
            }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history, [])

        XCTAssertEqual(helper.publisher.send(1), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(100))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                       .minimumTolerance,
                       .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                      interval: .nanoseconds(13),
                                                      tolerance: .nanoseconds(7),
                                                      options: .nontrivialOptions)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(3))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                       .minimumTolerance,
                       .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                      interval: .nanoseconds(13),
                                                      tolerance: .nanoseconds(7),
                                                      options: .nontrivialOptions)])

        scheduler.rewind(to: .nanoseconds(200))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                       .minimumTolerance,
                       .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                      interval: .nanoseconds(13),
                                                      tolerance: .nanoseconds(7),
                                                      options: .nontrivialOptions)])

        XCTAssertEqual(helper.publisher.send(2), .none)
        scheduler.rewind(to: .nanoseconds(250))
        XCTAssertEqual(helper.publisher.send(3), .none)
        scheduler.rewind(to: .nanoseconds(300))
        XCTAssertEqual(helper.publisher.send(4), .none)
        scheduler.rewind(to: .nanoseconds(350))
        XCTAssertEqual(helper.publisher.send(5), .none)
        scheduler.rewind(to: .nanoseconds(400))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(213),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(263),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(313),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(363),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))

        XCTAssertEqual(helper.publisher.send(6), .none)
        scheduler.rewind(to: .nanoseconds(450))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(213),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(263),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(313),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(363),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])
        XCTAssertEqual(scheduler.cancellableTokenDeinitCount, 5)
    }

    func testBadScheduler() throws {
        // What if the scheduler returns a cancellable that does nothing at all?

        let scheduler = VirtualTimeScheduler(
            cancellableTokenType: VirtualTimeScheduler.NoopCancellableToken.self
        )

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: {
                $0.debounce(for: .nanoseconds(13),
                            scheduler: scheduler,
                            options: .nontrivialOptions)
            }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        scheduler.rewind(to: .nanoseconds(2))
        XCTAssertEqual(helper.publisher.send(2), .none)
        scheduler.rewind(to: .nanoseconds(4))
        XCTAssertEqual(helper.publisher.send(3), .none)
        scheduler.rewind(to: .nanoseconds(6))

        XCTAssertEqual(helper.publisher.send(42), .none)
        scheduler.rewind(to: .nanoseconds(50))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .value(42)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(13),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(15),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(17),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.nanoseconds(19),
                                                       interval: .nanoseconds(13),
                                                       tolerance: .nanoseconds(7),
                                                       options: .nontrivialOptions)])

        XCTAssertEqual(scheduler.cancellableTokenDeinitCount, 0)

        // Cancel before due
        XCTAssertEqual(helper.publisher.send(1), .none)
        scheduler.rewind(to: .nanoseconds(54))
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        scheduler.rewind(to: .nanoseconds(100))

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"),
                                                 .value(42)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])
    }

    func testSetupTimerStrongCapture() {
        let scheduler = VirtualTimeScheduler()
        var subscriptionDestroyed = false
        do {
            let helper = OperatorTestHelper(
                publisherType: CustomPublisher.self,
                initialDemand: .unlimited,
                receiveValueDemand: .none,
                createSut: {
                    $0.debounce(for: .nanoseconds(13), scheduler: scheduler)
                }
            )

            helper.tracking.onDeinit = { subscriptionDestroyed = true }

            XCTAssertEqual(helper.publisher.send(1), .none)
        }

        XCTAssertFalse(subscriptionDestroyed)
    }

    func testDebounceWithImmediateScheduler() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(1),
            createSut: {
                $0.debounce(for: .nanoseconds(13),
                            scheduler: ImmediateScheduler.shared)
            }
        )

        _ = helper.publisher.send(1)

        XCTAssertEqual(helper.tracking.history, [.subscription("Debounce"), .value(1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testTimeoutReceiveValueBeforeSubscription() {
        let scheduler = VirtualTimeScheduler()
        testReceiveValueBeforeSubscription(
            value: 42,
            expected: .history([], demand: .none),
            { $0.debounce(for: .nanoseconds(13), scheduler: scheduler) }
        )
    }

    func testTimeoutReceiveCompletionBeforeSubscription() {
        let scheduler = VirtualTimeScheduler()
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.debounce(for: .nanoseconds(13), scheduler: scheduler) }
        )
    }

    func testTimeoutRequestBeforeSubscription() {
        let scheduler = VirtualTimeScheduler()
        testRequestBeforeSubscription(
            inputType: Int.self,
            shouldCrash: false,
            { $0.debounce(for: .nanoseconds(13), scheduler: scheduler) }
        )
    }

    func testTimeoutReceiveSubscriptionTwice() throws {
        let scheduler = VirtualTimeScheduler()

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.debounce(for: .nanoseconds(13), scheduler: scheduler) }
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
    }

    func testTimeoutCancelBeforeSubscription() {
        let scheduler = VirtualTimeScheduler()
        testCancelBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.timeout(.nanoseconds(13), scheduler: scheduler) }
        )
    }

    func testDebounceReflection() throws {
        let scheduler = VirtualTimeScheduler()
        try testReflection(
            parentInput: Int.self,
            parentFailure: Error.self,
            description: "Debounce",
            customMirror: expectedChildren(
                ("downstream", .contains("TrackingSubscriberBase")),
                ("downstreamDemand", "max(0)"),
                ("currentValue", "nil")
            ),
            playgroundDescription: "Debounce",
            { $0.debounce(for: .nanoseconds(13), scheduler: scheduler) }
        )
    }
}
