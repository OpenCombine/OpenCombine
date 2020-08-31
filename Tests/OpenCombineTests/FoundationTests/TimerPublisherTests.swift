//
//  TimerPublisherTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 23.06.2020.
//

import Foundation
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineFoundation
#endif

@available(macOS 10.15, iOS 13.0, *)
final class TimerPublisherTests: XCTestCase {

    private lazy var timerSubscription: StringSubscription = {
        let publisher: TimerPublisher = Timer
            .publish(every: 0.1, on: .main, in: .default)
        let tracking = TrackingSubscriberBase<Date, Never>()
        publisher.subscribe(tracking)
        let subscription = tracking.subscriptions.first
        return subscription.map(StringSubscription.init) ?? "No subscription"
    }()

    private func historyFromTicks(
        _ ticks: [TimeInterval]
    ) -> [TrackingSubscriberBase<Date, Never>.Event] {
        return [.subscription(timerSubscription)] +
            ticks.map { .value(Date(timeIntervalSinceReferenceDate: $0)) }
    }

    func testPublishMethod() {
        let publisher: TimerPublisher = Timer
            .publish(every: 0.25,
                     tolerance: 0.02,
                     on: .main,
                     in: RunLoop.Mode(rawValue: "testMode"),
                     options: nil)

        XCTAssertEqual(publisher.interval, 0.25)
        XCTAssertEqual(publisher.tolerance, nil)
        XCTAssertEqual(publisher.runLoop, .main)
        XCTAssertEqual(publisher.mode, RunLoop.Mode(rawValue: "testMode"))
        XCTAssertNil(publisher.options)
    }

    func testConnectAndPublish() {
        let desiredInterval: TimeInterval = 0.5

        var ticks1 = [TimeInterval]()
        var ticks2 = [TimeInterval]()
        var ticks3 = [TimeInterval]()

        // The total demand of tracking1 is 5
        let tracking1 = TrackingSubscriberBase<Date, Never>(
            receiveSubscription: {
                $0.request(.max(3))
            },
            receiveValue: {
                ticks1.append($0.timeIntervalSinceReferenceDate)
                return ticks1.count < 3 ? .max(1) : .none
            }
        )

        // The total demand of tracking2 is 2
        let tracking2 = TrackingSubscriberBase<Date, Never>(
            receiveSubscription: {
                $0.request(.max(2))
            },
            receiveValue: {
                ticks2.append($0.timeIntervalSinceReferenceDate)
                return .none
            }
        )

        // The total demand of tracking1 is 3
        let tracking3 = TrackingSubscriberBase<Date, Never>(
            receiveSubscription: {
                $0.request(.max(1))
            },
            receiveValue: {
                ticks3.append($0.timeIntervalSinceReferenceDate)
                return ticks3.count < 3 ? .max(1) : .none
            }
        )

        let publisher: TimerPublisher = Timer
            .publish(every: desiredInterval, on: .main, in: .default)

        publisher.subscribe(tracking1)
        publisher.subscribe(tracking2)
        publisher.subscribe(tracking3)

        XCTAssertEqual(tracking1.history, [.subscription(timerSubscription)])

        RunLoop.main.run(until: Date() + 1)

        // Test that no output is produced until we connect
        XCTAssertEqual(tracking1.history, [.subscription(timerSubscription)])

        let connection = publisher.connect()

        RunLoop.main.run(until: Date() + 10)

        assertCorrectIntervals(ticks: ticks1,
                               expectedNumberOfTicks: 5,
                               desiredInterval: desiredInterval)
        assertCorrectIntervals(ticks: ticks2,
                               expectedNumberOfTicks: 2,
                               desiredInterval: desiredInterval)
        assertCorrectIntervals(ticks: ticks3,
                               expectedNumberOfTicks: 3,
                               desiredInterval: desiredInterval)

        // The first dates should be exactly the same!
        XCTAssert(Array(ticks1.prefix(2)) == ticks2)
        XCTAssert(Array(ticks1.prefix(3)) == ticks3)

        connection.cancel()
        XCTAssertFalse(connection is Subscription)

        RunLoop.main.run(until: Date() + 1)

        XCTAssertEqual(tracking1.history, historyFromTicks(ticks1))
        XCTAssertEqual(tracking2.history, historyFromTicks(ticks2))
        XCTAssertEqual(tracking3.history, historyFromTicks(ticks3))
    }

    func testConnectMultipleTimes() throws {
        let publisher = TimerPublisher(interval: 0.5,
                                       runLoop: .main,
                                       mode: .default)

        let tracking = TrackingSubscriberBase<Date, Never>()

        publisher.subscribe(tracking)

        let connection1 = publisher.connect()
        let connection2 = publisher.connect()

        // Two connections should correspond to two different timers.

        RunLoop.main.run(until: Date() + 5)
        let numberOfTicks = tracking.history.count
        XCTAssertNotEqual(numberOfTicks, 10)

        // Cancelling one connection prevents publishing even if another connection
        // is still active.
        connection1.cancel()
        RunLoop.main.run(until: Date() + 2)
        XCTAssertEqual(tracking.history.count, numberOfTicks)

        connection2.cancel()
    }

    func testConnectionReflection() throws {
        let publisher = TimerPublisher(interval: 0.25,
                                       tolerance: 0.4,
                                       runLoop: .main,
                                       mode: .default,
                                       options: nil)

        let connection = publisher.connect()
        defer { connection.cancel() }

        XCTAssertFalse(connection is CustomStringConvertible)
        XCTAssertFalse(connection is CustomPlaygroundDisplayConvertible)
        XCTAssertFalse(connection is CustomReflectable)
        XCTAssertFalse(connection is CustomDebugStringConvertible)

        let tracking = TrackingSubscriberBase<Date, Never>()
        publisher.subscribe(tracking)

        let subscription = try XCTUnwrap(tracking.subscriptions.first?.underlying)

        XCTAssertFalse(subscription is NSObject)
        XCTAssertFalse(subscription is CustomStringConvertible)
        XCTAssertFalse(subscription is CustomPlaygroundDisplayConvertible)
        XCTAssertFalse(subscription is CustomReflectable)
        XCTAssertFalse(subscription is CustomDebugStringConvertible)
    }

    private func assertCorrectIntervals(ticks: [TimeInterval],
                                        expectedNumberOfTicks: Int,
                                        desiredInterval: TimeInterval) {
        XCTAssertEqual(ticks.count, expectedNumberOfTicks)

        if ticks.isEmpty { return }

        let actualIntervals = zip(ticks.dropFirst(), ticks.dropLast()).map(-)
        let averageInterval =
            actualIntervals.reduce(0, +) / TimeInterval(actualIntervals.count)

        XCTAssertEqual(averageInterval,
                       desiredInterval,
                       accuracy: desiredInterval / 2,
                       """
                       Actual average interval (\(averageInterval)) deviates from \
                       desired interval (\(desiredInterval)) too much.

                       Actual intervals: \(actualIntervals)
                       """)
    }
}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)
@available(macOS 10.15, iOS 13.0, *)
private typealias TimerPublisher = Timer.TimerPublisher
#else
private typealias TimerPublisher = Timer.OCombine.TimerPublisher
#endif
