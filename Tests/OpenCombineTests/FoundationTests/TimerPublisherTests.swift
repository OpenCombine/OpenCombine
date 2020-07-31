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
        var ticks = [TimeInterval]()

        let tracking1 = TrackingSubscriberBase<Date, Never>(
            receiveSubscription: {
                $0.request(.max(3))
            },
            receiveValue: {
                ticks.append($0.timeIntervalSinceReferenceDate)
                return ticks.count < 3 ? .max(1) : .none
            }
        )

        let tracking2 = TrackingSubscriberBase<Date, Never>(
            receiveSubscription: {
                $0.request(.max(2))
            }
        )
        let tracking3 = TrackingSubscriberBase<Date, Never>(
            receiveSubscription: {
                $0.request(.max(1))
            },
            receiveValue: { _ in
                ticks.count < 3 ? .max(1) : .none
            }
        )

        let publisher: TimerPublisher = Timer
            .publish(every: desiredInterval, on: .main, in: .default)

        publisher.subscribe(tracking1)
        publisher.subscribe(tracking2)
        publisher.subscribe(tracking3)

        XCTAssertEqual(tracking1.history, [.subscription("Timer")])

        RunLoop.main.run(until: Date() + 1)

        // Test that no output is produced until we connect
        XCTAssertEqual(tracking1.history, [.subscription("Timer")])

        let connection = publisher.connect()

        RunLoop.main.run(until: Date() + 10)

        assertCorrectIntervals(ticks: ticks,
                               expectedNumberOfTicks: 10,
                               desiredInterval: desiredInterval)

        let fullHistory =
            [TrackingSubscriberBase<Date, Never>.Event.subscription("Timer")] +
                ticks.map { .value(Date(timeIntervalSinceReferenceDate: $0)) }

        connection.cancel()
        XCTAssert(connection is Subscription)

        RunLoop.main.run(until: Date() + 1)

        XCTAssertEqual(tracking1.history, fullHistory)
        XCTAssertEqual(tracking2.history, fullHistory)
        XCTAssertEqual(tracking3.history, fullHistory)
    }

    func testConnectAndCancelMultipleTimes() throws {
        let publisher = TimerPublisher(interval: 0.25,
                                       runLoop: .main,
                                       mode: .default)

        let tracking = TrackingSubscriberBase<Date, Never>()

        publisher.subscribe(tracking)

        let connection1 = publisher.connect()
        let connection2 = publisher.connect()
        XCTAssert((connection1 as AnyObject) === (connection2 as AnyObject))

        connection1.cancel()
        connection1.cancel()

        let connection3 = try XCTUnwrap(publisher.connect() as? Subscription)
        connection3.request(.max(1))

        RunLoop.main.run(until: Date() + 0.3)

        XCTAssertEqual(tracking.history, [.subscription("Timer")])
    }

    func testConnectionReflection() throws {
        let publisher = TimerPublisher(interval: 0.25,
                                       tolerance: 0.4,
                                       runLoop: .main,
                                       mode: .default,
                                       options: nil)

        let connection = publisher.connect()
        defer { connection.cancel() }

        XCTAssertEqual(
            (connection as? CustomStringConvertible)?.description,
            "Timer"
        )
        XCTAssertEqual(
            (connection as? CustomPlaygroundDisplayConvertible)?
                .playgroundDescription as? String,
            "Timer"
        )
        XCTAssertFalse(connection is CustomDebugStringConvertible)

        let connectionCombineID =
            try XCTUnwrap(connection as? CustomCombineIdentifierConvertible)
                .combineIdentifier

        guard let inner = Mirror(reflecting: connection).descendant("some")
        else {
            XCTFail("Unexpected representation")
            return
        }

        expectedChildren(
            ("downstream", "Optional(Timer)"),
            ("interval", "Optional(0.25)"),
            ("tolerance", "Optional(0.4)")
        )(Mirror(reflecting: inner))

        connection.cancel()

        expectedChildren(
            ("downstream", "nil"),
            ("interval", "nil"),
            ("tolerance", "nil")
        )(Mirror(reflecting: inner))

        XCTAssert(inner is NSObject)

        XCTAssertEqual(
            (inner as? CustomStringConvertible)?.description,
            "Timer"
        )
        XCTAssertEqual(
            (inner as? CustomPlaygroundDisplayConvertible)?
                .playgroundDescription as? String,
            "Timer"
        )
        XCTAssertEqual(
            (inner as? CustomDebugStringConvertible)?.debugDescription,
            "Timer"
        )

        let innerCombineID =
            try XCTUnwrap(inner as? CustomCombineIdentifierConvertible)
                .combineIdentifier

        XCTAssertEqual(connectionCombineID, innerCombineID)
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
