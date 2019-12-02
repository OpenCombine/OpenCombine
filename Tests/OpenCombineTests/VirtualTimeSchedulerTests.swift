//
//  VirtualTimeSchedulerTests.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 14/09/2019.
//

import XCTest

class VirtualTimeSchedulerTests: XCTestCase {

    func testOrder() {
        let scheduler = VirtualTimeScheduler()
        var results: [Int] = []

        let date1 = scheduler.now.advanced(by: 2)
        scheduler.schedule(after: date1, tolerance: 0, options: nil) {
            results.append(4)
        }
        scheduler.schedule {
            results.append(1)
        }
        let date2 = scheduler.now.advanced(by: 1)
        scheduler.schedule(after: date2, tolerance: 0, options: nil) {
            results.append(3)
        }
        scheduler.schedule {
            results.append(2)
        }
        scheduler.flush()
        XCTAssertTrue(results == [1, 2, 3, 4])
    }

    func testStride() {
        let date1 = VirtualTimeScheduler.SchedulerTimeType(date: 0)
        let date2 = VirtualTimeScheduler.SchedulerTimeType(date: 2)
        XCTAssert(date2 > date1)
        let distance = date1.distance(to: date2)
        XCTAssert(distance.magnitude == 2)
        let date3 = date1.advanced(by: distance)
        XCTAssert(date2 == date3)
    }
}
