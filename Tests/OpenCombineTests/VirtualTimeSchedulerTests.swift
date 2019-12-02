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

        XCTAssertEqual(scheduler.now, .init(nanoseconds: 0))
        XCTAssertEqual(scheduler.scheduledDates, [.init(nanoseconds: 0),
                                                  .init(nanoseconds: 0),
                                                  .init(nanoseconds: 5),
                                                  .init(nanoseconds: 10)])

        scheduler.executeScheduledActions()
        XCTAssertEqual(history, [1, 2, 3, 4, 5])
        XCTAssertEqual(scheduler.now, .init(nanoseconds: 10))
        XCTAssertEqual(scheduler.scheduledDates, [])

        XCTAssertEqual(scheduler.history, [.now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.init(nanoseconds: 10),
                                                              tolerance: 0),
                                           .schedule,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.init(nanoseconds: 5),
                                                              tolerance: 0),
                                           .schedule,
                                           .now,
                                           .now,
                                           .minimumTolerance,
                                           .scheduleAfterDate(.init(nanoseconds: 7),
                                                              tolerance: 0),
                                           .now])
    }

    func testRepeadedAction() {
        let scheduler = VirtualTimeScheduler()
        var history = [Int]()
        let cancellable = scheduler.schedule(after: scheduler.now + .microseconds(2),
                                             interval: .milliseconds(40)) {
            history.append(Int(scheduler.now.time))
        }
        scheduler.schedule(after: scheduler.now + .milliseconds(300)) {
            cancellable.cancel()
        }
        XCTAssertEqual(scheduler.scheduledDates, [.init(nanoseconds: 2_000),
                                                  .init(nanoseconds: 300_000_000)])
        scheduler.executeScheduledActions()

        XCTAssertEqual(history, [2000,
                                 40002000,
                                 80002000,
                                 120002000,
                                 160002000,
                                 200002000,
                                 240002000,
                                 280002000])
        XCTAssertEqual(scheduler.now, .init(nanoseconds: 320002000))
        XCTAssertEqual(scheduler.history,
                       [.now,
                        .minimumTolerance,
                        .scheduleAfterDateWithInterval(.init(nanoseconds: 2000),
                                                       interval: .nanoseconds(40000000),
                                                       tolerance: 0),
                        .now,
                        .minimumTolerance,
                        .scheduleAfterDate(.init(nanoseconds: 300000000),
                                           tolerance: .nanoseconds(0)),
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
}
