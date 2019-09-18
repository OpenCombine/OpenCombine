//
//  DispatchQueueSchedulerTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 26.08.2019.
//

import Dispatch
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineDispatch
#endif

@available(macOS 10.15, iOS 13.0, *)
final class DispatchQueueSchedulerTests: XCTestCase {

    // MARK: - Scheduler.SchedulerTimeType

    func testSchedulerTimeTypeDistance() {
        let time1 = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10000))
        let time2 = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10431))

        XCTAssertEqual(time1.distance(to: time2), .nanoseconds(431))

        // A bug in Combine (FB7127210), caused by overflow on subtraction.
        // It should not crash. When they fix it, this test will fail and we'll know
        // that we need to update our implementation.
        assertCrashes {
            _ = time2.distance(to: time1)
        }
    }

    func testSchedulerTimeTypeAdvanced() {
        let time = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10000))
        let stride1 = Scheduler.SchedulerTimeType.Stride.nanoseconds(431)
        let stride2 = Scheduler.SchedulerTimeType.Stride.nanoseconds(-220)

        XCTAssertEqual(time.advanced(by: stride1),
                       Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10431)))

        XCTAssertEqual(time.advanced(by: stride2),
                       Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 9780)))
    }

    func testSchedulerTimeTypeEquatable() {
        let time1 = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10000))
        let time2 = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10000))
        let time3 = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10001))

        XCTAssertEqual(time1, time1)
        XCTAssertEqual(time2, time2)
        XCTAssertEqual(time3, time3)

        XCTAssertEqual(time1, time2)
        XCTAssertEqual(time2, time1)
        XCTAssertNotEqual(time1, time3)

        assertCrashes {
            XCTAssertNotEqual(time3, time1)
        }
    }

    func testSchedulerTimeTypeHashable() {
        let time1 = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10000))
        let time2 = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10001))

        XCTAssertEqual(time1.hashValue, time1.dispatchTime.rawValue.hashValue)
        XCTAssertEqual(time2.hashValue, time2.dispatchTime.rawValue.hashValue)
    }

    func testSchedulerTimeTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let time = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 42))
        let encodedData = try encoder
            .encode(KeyedWrapper(value: time))
        let encodedString = String(decoding: encodedData, as: UTF8.self)

        XCTAssertEqual(encodedString, #"{"value":42}"#)

        let decodedTime = try decoder
            .decode(KeyedWrapper<Scheduler.SchedulerTimeType>.self, from: encodedData)
            .value

        XCTAssertEqual(decodedTime, time)
    }

    // MARK: - Scheduler.SchedulerTimeType.Stride

    func testStrideToDispatchTimeInterval() {
        typealias Stride = Scheduler.SchedulerTimeType.Stride

        switch (Stride.seconds(12).timeInterval,
                Stride.milliseconds(34).timeInterval,
                Stride.microseconds(56).timeInterval,
                Stride.nanoseconds(78).timeInterval) {
        case (.nanoseconds(12000000000),
              .nanoseconds(34000000),
              .nanoseconds(56000),
              .nanoseconds(78)):
            break // pass
        case let intervals:
            XCTFail("Unexpected DispatchTimeInterval: \(intervals)")
        }
    }

    func testStrideFromDispatchTimeInterval() {
        typealias Stride = Scheduler.SchedulerTimeType.Stride

        XCTAssertEqual(Stride(.seconds(12)).magnitude, 12000000000)
        XCTAssertEqual(Stride(.milliseconds(34)).magnitude, 34000000)
        XCTAssertEqual(Stride(.microseconds(56)).magnitude, 56000)
        XCTAssertEqual(Stride(.nanoseconds(78)).magnitude, 78)
        XCTAssertEqual(Stride(.never).magnitude, .max)
    }

    func testStrideFromNumericValue() {
        typealias Stride = Scheduler.SchedulerTimeType.Stride

        XCTAssertEqual(Stride.seconds(12.756).magnitude, 12756000000)
        XCTAssertEqual(Stride.seconds(34).magnitude, 34000000000)
        XCTAssertEqual(Stride.milliseconds(56).magnitude, 56000000)
        XCTAssertEqual(Stride.microseconds(78).magnitude, 78000)
        XCTAssertEqual(Stride.nanoseconds(90).magnitude, 90)

        XCTAssertEqual((12.756 as Stride).magnitude, 12756000000)
        XCTAssertEqual((34 as Stride).magnitude, 34000000000)

        XCTAssertNil(Stride(exactly: UInt64.max))
        XCTAssertEqual(Stride(exactly: 871 as UInt64)?.magnitude, 871)
    }

    func testStrideComparable() {
        typealias Stride = Scheduler.SchedulerTimeType.Stride

        XCTAssertLessThan(Stride.nanoseconds(1), .nanoseconds(2))
        XCTAssertGreaterThan(Stride.nanoseconds(-2), .microseconds(-10))
        XCTAssertLessThan(Stride.milliseconds(29), .seconds(29))
    }

    func testStrideMultiplication() {
        typealias Stride = Scheduler.SchedulerTimeType.Stride

        XCTAssertEqual((Stride.nanoseconds(0) * .nanoseconds(61346)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(61346) * .nanoseconds(0)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(18) * .nanoseconds(1)).magnitude,
                       18000000000)
        XCTAssertEqual((Stride.nanoseconds(18) * .microseconds(1)).magnitude,
                       18000000000000)
        XCTAssertEqual((Stride.nanoseconds(1) * .nanoseconds(18)).magnitude,
                       18000000000)
        XCTAssertEqual((Stride.microseconds(1) * .nanoseconds(18)).magnitude,
                       18000000000000)
        XCTAssertEqual((Stride.nanoseconds(15) * .nanoseconds(2)).magnitude,
                       30000000000)
        XCTAssertEqual((Stride.microseconds(-3) * .nanoseconds(10)).magnitude,
                       -30000000000000)

        do {
            var stride = Stride.nanoseconds(0)
            stride *= .nanoseconds(61346)
            XCTAssertEqual(stride.magnitude, 0)
        }

        do {
            var stride = Stride.nanoseconds(61346)
            stride *= .nanoseconds(0)
            XCTAssertEqual(stride.magnitude, 0)
        }

        do {
            var stride = Stride.nanoseconds(18)
            stride *= .nanoseconds(1)
            XCTAssertEqual(stride.magnitude, 18000000000)
        }

        do {
            var stride = Stride.nanoseconds(18)
            stride *= .microseconds(1)
            XCTAssertEqual(stride.magnitude, 18000000000000)
        }

        do {
            var stride = Stride.nanoseconds(1)
            stride *= .nanoseconds(18)
            XCTAssertEqual(stride.magnitude, 18000000000)
        }

        do {
            var stride = Stride.microseconds(1)
            stride *= .nanoseconds(18)
            XCTAssertEqual(stride.magnitude, 18000000000000)
        }

        do {
            var stride = Stride.nanoseconds(15)
            stride *= .nanoseconds(2)
            XCTAssertEqual(stride.magnitude, 30000000000)
        }

        do {
            var stride = Stride.microseconds(-3)
            stride *= .nanoseconds(10)
            XCTAssertEqual(stride.magnitude, -30000000000000)
        }
    }

    func testStrideAddition() {
        typealias Stride = Scheduler.SchedulerTimeType.Stride

        XCTAssertEqual((Stride.nanoseconds(0) + .microseconds(2)).magnitude,
                       2000000000000)
        XCTAssertEqual((Stride.nanoseconds(2) + .microseconds(0)).magnitude,
                       2000000000)
        XCTAssertEqual((Stride.nanoseconds(7) + .nanoseconds(12)).magnitude,
                       19000000000)
        XCTAssertEqual((Stride.nanoseconds(12) + .nanoseconds(7)).magnitude,
                       19000000000)
        XCTAssertEqual((Stride.nanoseconds(7) + .nanoseconds(-12)).magnitude,
                       -5000000000)
        XCTAssertEqual((Stride.nanoseconds(-12) + .nanoseconds(7)).magnitude,
                       -5000000000)

        do {
            var stride = Stride.nanoseconds(0)
            stride += .microseconds(2)
            XCTAssertEqual(stride.magnitude, 2000000000000)
        }

        do {
            var stride = Stride.nanoseconds(2)
            stride += .microseconds(0)
            XCTAssertEqual(stride.magnitude, 2000000000)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride += .nanoseconds(12)
            XCTAssertEqual(stride.magnitude, 19000000000)
        }

        do {
            var stride = Stride.nanoseconds(12)
            stride += .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, 19000000000)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride += .nanoseconds(-12)
            XCTAssertEqual(stride.magnitude, -5000000000)
        }

        do {
            var stride = Stride.nanoseconds(-12)
            stride += .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, -5000000000)
        }
    }

    func testStrideSubtraction() {
        typealias Stride = Scheduler.SchedulerTimeType.Stride

        XCTAssertEqual((Stride.nanoseconds(0) - .microseconds(2)).magnitude,
                       -2000000000000)
        XCTAssertEqual((Stride.nanoseconds(2) - .microseconds(0)).magnitude,
                       2000000000)
        XCTAssertEqual((Stride.nanoseconds(7) - .nanoseconds(12)).magnitude,
                       -5000000000)
        XCTAssertEqual((Stride.nanoseconds(12) - .nanoseconds(7)).magnitude,
                       5000000000)
        XCTAssertEqual((Stride.nanoseconds(7) - .nanoseconds(-12)).magnitude,
                       19000000000)
        XCTAssertEqual((Stride.nanoseconds(-12) - .nanoseconds(7)).magnitude,
                       -19000000000)

        do {
            var stride = Stride.nanoseconds(0)
            stride -= .microseconds(2)
            XCTAssertEqual(stride.magnitude, -2000000000000)
        }

        do {
            var stride = Stride.nanoseconds(2)
            stride -= .microseconds(0)
            XCTAssertEqual(stride.magnitude, 2000000000)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride -= .nanoseconds(12)
            XCTAssertEqual(stride.magnitude, -5000000000)
        }

        do {
            var stride = Stride.nanoseconds(12)
            stride -= .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, 5000000000)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride -= .nanoseconds(-12)
            XCTAssertEqual(stride.magnitude, 19000000000)
        }

        do {
            var stride = Stride.nanoseconds(-12)
            stride -= .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, -19000000000)
        }
    }

    func testStrideCodable() throws {
        typealias Stride = Scheduler.SchedulerTimeType.Stride

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let stride = Stride.nanoseconds(419872)
        let encodedData = try encoder
            .encode(KeyedWrapper(value: stride))
        let encodedString = String(decoding: encodedData, as: UTF8.self)

        XCTAssertEqual(encodedString, #"{"value":{"magnitude":419872}}"#)

        let decodedStride = try decoder
            .decode(KeyedWrapper<Stride>.self, from: encodedData)
            .value

        XCTAssertEqual(decodedStride, stride)
    }

    // MARK: - Scheduler

    func testMinimumTolerance() {
        XCTAssertEqual(mainScheduler.minimumTolerance, .nanoseconds(0))
        XCTAssertEqual(backgroundScheduler.minimumTolerance, .nanoseconds(0))
    }

    func testNow() {
        let expectedNow = DispatchTime.now().uptimeNanoseconds
        let actualNowMainScheduler = mainScheduler
            .now
            .dispatchTime
            .uptimeNanoseconds
        let actualNowBackgroundScheduler = backgroundScheduler
            .now
            .dispatchTime
            .uptimeNanoseconds
        XCTAssertLessThan(abs(actualNowMainScheduler.distance(to: expectedNow)),
                          500_000/*nanoseconds*/)
        XCTAssertLessThan(abs(actualNowBackgroundScheduler.distance(to: expectedNow)),
                          500_000/*nanoseconds*/)
    }

    func testDefaultSchedulerOptions() {
        let options = Scheduler.SchedulerOptions()
        XCTAssertEqual(options.flags, [])
        XCTAssertEqual(options.qos, .unspecified)
        XCTAssertNil(options.group)
    }

    func testScheduleActionOnceNow() {
        let main = expectation(description: "scheduled on main queue")
        main.assertForOverFulfill = true

        var didExecuteMainAction = false
        let didExecuteBackgroundAction = Atomic(false)

        mainScheduler.schedule {
            didExecuteMainAction = true
            main.fulfill()
        }

        let group = DispatchGroup()

        backgroundScheduler
            .schedule(options: .init(qos: .userInteractive, group: group)) {
                didExecuteBackgroundAction.do { $0 = true }
            }

        XCTAssertFalse(didExecuteMainAction, "action should be executed asynchronously")

        // Wait for the background scheduler to execute the work.
        XCTAssertEqual(group.wait(timeout: .now() + 0.1), .success)

        XCTAssertFalse(didExecuteMainAction, "action should be executed asynchronously")
        XCTAssertTrue(didExecuteBackgroundAction.value)

        wait(for: [main], timeout: 0.1)
    }

    func testScheduleActionOnceLater() {

        let main = expectation(description: "scheduled on main queue")
        main.assertForOverFulfill = true

        var didExecuteAction = false

        let delay = Scheduler.SchedulerTimeType.Stride.milliseconds(200)

        mainScheduler.schedule(after: mainScheduler.now.advanced(by: delay)) {
            didExecuteAction = true
            main.fulfill()
        }

        XCTAssertFalse(didExecuteAction, "action should be executed asynchronously")

        wait(for: [main], timeout: 3/*seconds*/)
    }

    func testScheduleRepeating() {
        let main = expectation(description: "scheduled on main queue")
        main.expectedFulfillmentCount = 4
        main.assertForOverFulfill = true

        let delay = Scheduler.SchedulerTimeType.Stride.milliseconds(100)
        let interval = Scheduler.SchedulerTimeType.Stride.milliseconds(50)

        var didExecuteAction = false

        let token = mainScheduler
            .schedule(after: mainScheduler.now.advanced(by: delay),
                      interval: interval) {
                didExecuteAction = true
                main.fulfill()
            }

        XCTAssert(token is AnyCancellable)
        XCTAssertFalse(didExecuteAction, "action should be executed asynchronously")

        wait(for: [main], timeout: 3/*seconds*/)
    }
}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)

@available(macOS 10.15, iOS 13.0, *)
private typealias Scheduler = DispatchQueue

private let mainScheduler = DispatchQueue.main
private let backgroundScheduler = DispatchQueue.global(qos: .background)

#else

private typealias Scheduler = DispatchQueue.OCombine

private let mainScheduler = DispatchQueue.main.ocombine
private let backgroundScheduler = DispatchQueue.global(qos: .background).ocombine

#endif

private struct KeyedWrapper<Value: Codable & Equatable>: Codable, Equatable {
    let value: Value
}
