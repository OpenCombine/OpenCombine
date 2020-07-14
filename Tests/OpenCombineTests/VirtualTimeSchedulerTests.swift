//
//  VirtualTimeSchedulerTests.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 14/09/2019.
//

import XCTest

@available(macOS 10.15, iOS 13.0, *)
final class VirtualTimeSchedulerTests: XCTestCase {

    func testOrder() {
        var history = [Int]()
        let scheduler = VirtualTimeScheduler()
        scheduler.schedule(after: scheduler.now + .nanoseconds(10)) {
            history.append(5)
        }
        scheduler.schedule {
            history.append(1)
        }
        scheduler.schedule(after: scheduler.now + .nanoseconds(5)) {
            history.append(3)
            scheduler.schedule(after: scheduler.now + .nanoseconds(2)) {
                history.append(4)
            }
        }
        scheduler.schedule {
            history.append(2)
        }

        XCTAssertEqual(scheduler.now, .nanoseconds(0))
        XCTAssertEqual(scheduler.scheduledDates, [.nanoseconds(0),
                                                  .nanoseconds(0),
                                                  .nanoseconds(5),
                                                  .nanoseconds(10)])

        scheduler.executeScheduledActions()
        XCTAssertEqual(history, [1, 2, 3, 4, 5])
        XCTAssertEqual(scheduler.now, .nanoseconds(10))
        XCTAssertEqual(scheduler.scheduledDates, [])

        XCTAssertEqual(scheduler.history, [.now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.nanoseconds(10),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .schedule(options: nil),
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.nanoseconds(5),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .schedule(options: nil),
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.nanoseconds(7),
                                                              tolerance: .nanoseconds(7),
                                                              options: nil),
                                           .now])
    }

    func testRepeatedAction() {
        let scheduler = VirtualTimeScheduler()
        var history = [Int]()
        let cancellable = scheduler.schedule(after: scheduler.now + .microseconds(2),
                                             interval: .milliseconds(40)) {
            history.append(Int(scheduler.now.time))
        }
        scheduler.schedule(after: scheduler.now + .milliseconds(300)) {
            cancellable.cancel()
        }
        XCTAssertEqual(scheduler.scheduledDates, [.microseconds(2), .milliseconds(300)])
        scheduler.executeScheduledActions()

        XCTAssertEqual(history, [2000,
                                 40002000,
                                 80002000,
                                 120002000,
                                 160002000,
                                 200002000,
                                 240002000,
                                 280002000])
        XCTAssertEqual(scheduler.now, .microseconds(320002))
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.microseconds(2),
                                                       interval: .milliseconds(40),
                                                       tolerance: .nanoseconds(7),
                                                       options: nil),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDate(.milliseconds(300),
                                           tolerance: .nanoseconds(7),
                                           options: nil),
                        .now,
                        .now,
                        .now,
                        .now,
                        .now,
                        .now,
                        .now,
                        .now,
                        .now])
    }

    func testRewindForward() {
        let scheduler = VirtualTimeScheduler()
        var history = [Int]()
        let cancellable = scheduler.schedule(after: scheduler.now + .microseconds(2),
                                             interval: .milliseconds(40)) {
            history.append(Int(scheduler.now.time))
        }
        scheduler.schedule(after: scheduler.now + .milliseconds(300)) {
            cancellable.cancel()
        }
        XCTAssertEqual(scheduler.scheduledDates, [.microseconds(2), .milliseconds(300)])
        scheduler.rewind(to: .milliseconds(81))

        XCTAssertEqual(history, [2000,
                                 40002000,
                                 80002000])

        scheduler.executeScheduledActions()

        XCTAssertEqual(history, [2000,
                                 40002000,
                                 80002000,
                                 120002000,
                                 160002000,
                                 200002000,
                                 240002000,
                                 280002000])

        scheduler.rewind(to: .milliseconds(0))
        scheduler.executeScheduledActions()

        XCTAssertEqual(history, [2000,
                                 40002000,
                                 80002000,
                                 120002000,
                                 160002000,
                                 200002000,
                                 240002000,
                                 280002000])
    }
}
