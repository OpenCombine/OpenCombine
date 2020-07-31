//
//  RunLoopSchedulerTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.12.2019.
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
final class RunLoopSchedulerTests: XCTestCase {

    // MARK: - Scheduler.SchedulerTimeType

    func testSchedulerTimeTypeDistance() {
        RunLoopSchedulerTests.testSchedulerTimeTypeDistance(RunLoopScheduler.self)
    }

    static func testSchedulerTimeTypeDistance<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        let time1 = Context.SchedulerTimeType(Date(timeIntervalSince1970: 10_000))
        let time2 = Context.SchedulerTimeType(Date(timeIntervalSince1970: 10_431))
        let distantFuture = Context.SchedulerTimeType(.distantFuture)
        let notSoDistantFuture = Context.SchedulerTimeType(
            Date.distantFuture - 1024
        )

        XCTAssertEqual(time1.distance(to: time2).timeInterval, 431)
        XCTAssertEqual(time2.distance(to: time1).timeInterval, -431)

        XCTAssertEqual(time1.distance(to: distantFuture).timeInterval, 64_092_201_200)
        XCTAssertEqual(distantFuture.distance(to: time1).timeInterval, -64_092_201_200)
        XCTAssertEqual(time2.distance(to: distantFuture).timeInterval, 64_092_200_769)
        XCTAssertEqual(distantFuture.distance(to: time2).timeInterval, -64_092_200_769)

        XCTAssertEqual(time1.distance(to: notSoDistantFuture).timeInterval,
                       64_092_200_176)
        XCTAssertEqual(notSoDistantFuture.distance(to: time1).timeInterval,
                       -64_092_200_176)
        XCTAssertEqual(time2.distance(to: notSoDistantFuture).timeInterval,
                       64_092_199_745)
        XCTAssertEqual(notSoDistantFuture.distance(to: time2).timeInterval,
                       -64_092_199_745)

        XCTAssertEqual(distantFuture.distance(to: distantFuture).timeInterval,
                       0)
        XCTAssertEqual(notSoDistantFuture.distance(to: notSoDistantFuture).timeInterval,
                       0)
    }

    func testSchedulerTimeTypeAdvanced() {
        RunLoopSchedulerTests.testSchedulerTimeTypeAdvanced(RunLoopScheduler.self)
    }

    static func testSchedulerTimeTypeAdvanced<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        let time =
            Context.SchedulerTimeType(Date(timeIntervalSinceReferenceDate: 10_000))
        let beginningOfTime =
            Context.SchedulerTimeType(Date(timeIntervalSinceReferenceDate: 1))
        let stride1 = Context.SchedulerTimeType.Stride.seconds(431)
        let stride2 = Context.SchedulerTimeType.Stride.seconds(-220)

        XCTAssertEqual(time.advanced(by: stride1),
                       .init(Date(timeIntervalSinceReferenceDate: 10431)))

        XCTAssertEqual(time.advanced(by: stride2),
                       .init(Date(timeIntervalSinceReferenceDate: 9780)))

#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        // 64-bit platforms
        XCTAssertEqual(time.advanced(by: .nanoseconds(.max)).date,
                       Date(timeIntervalSinceReferenceDate: 9223382036.854776))

        XCTAssertEqual(time.advanced(by: .seconds(.max)).date,
                       Date(timeIntervalSinceReferenceDate: 9.223372036854786E+18))
#elseif arch(i386) || arch(arm)
        // 32-bit platforms
        XCTAssertEqual(time.advanced(by: .nanoseconds(.max)).date,
                       Date(timeIntervalSinceReferenceDate: 10002.147483647))

        XCTAssertEqual(time.advanced(by: .seconds(.max)).date,
                       Date(timeIntervalSinceReferenceDate: 2147493647))
#else
#error("This architecture isn't known. Add it to the 32-bit or 64-bit line.")
#endif

        XCTAssertEqual(beginningOfTime.advanced(by: .nanoseconds(-1000)).date,
                       Date(timeIntervalSinceReferenceDate: 0.999999))

        XCTAssertEqual(beginningOfTime.advanced(by: .seconds(-1000)).date,
                       Date(timeIntervalSinceReferenceDate: -999.0))
    }

    func testSchedulerTimeTypeEquatable() {
        RunLoopSchedulerTests.testSchedulerTimeTypeEquatable(RunLoopScheduler.self)
    }

    static func testSchedulerTimeTypeEquatable<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        let time1 = Context.SchedulerTimeType(Date(timeIntervalSinceReferenceDate: 10000))
        let time2 = Context.SchedulerTimeType(Date(timeIntervalSinceReferenceDate: 10000))
        let time3 = Context.SchedulerTimeType(Date(timeIntervalSinceReferenceDate: 10001))

        XCTAssertEqual(time1, time1)
        XCTAssertEqual(time2, time2)
        XCTAssertEqual(time3, time3)

        XCTAssertEqual(time1, time2)
        XCTAssertEqual(time2, time1)
        XCTAssertNotEqual(time1, time3)
        XCTAssertNotEqual(time3, time1)
    }

    func testSchedulerTimeTypeCodable() throws {
        try RunLoopSchedulerTests.testSchedulerTimeTypeCodable(RunLoopScheduler.self)
    }

    static func testSchedulerTimeTypeCodable<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let time =
            Context.SchedulerTimeType(Date(timeIntervalSinceReferenceDate: 1024.75))
        let encodedData = try encoder
            .encode(time)
        let encodedString = String(decoding: encodedData, as: UTF8.self)

        XCTAssertEqual(encodedString,
                       #"{"date":1024.75}"#)

        let decodedTime = try decoder
            .decode(Context.SchedulerTimeType.self, from: encodedData)

        XCTAssertEqual(decodedTime, time)
    }

    // MARK: - Scheduler.SchedulerTimeType.Stride

    func testStrideToTimeInterval() {
        RunLoopSchedulerTests.testStrideToTimeInterval(RunLoopScheduler.self)
    }

    static func testStrideToTimeInterval<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        typealias Stride = Context.SchedulerTimeType.Stride
        XCTAssertEqual(Stride.seconds(2).timeInterval, 2)
        XCTAssertEqual(Stride.seconds(2.2).timeInterval, 2.2)
        XCTAssertEqual(Stride.seconds(Double.infinity).timeInterval, .infinity)
        XCTAssertEqual(Stride.milliseconds(2).timeInterval, 0.002)
        XCTAssertEqual(Stride.microseconds(2).timeInterval, 2E-06)
        XCTAssertEqual(Stride.nanoseconds(2).timeInterval, 2E-09)
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        // 64-bit platforms
        XCTAssertEqual(Stride.seconds(Int.max).timeInterval, 9.223372036854776E+18)
        XCTAssertEqual(Stride.milliseconds(.max).timeInterval, 9.223372036854776E+15)
        XCTAssertEqual(Stride.microseconds(.max).timeInterval, 9223372036854.775)
        XCTAssertEqual(Stride.nanoseconds(.max).timeInterval, 9223372036.854776)
#elseif arch(i386) || arch(arm)
        // 32-bit platforms
        XCTAssertEqual(Stride.seconds(Int.max).timeInterval, 2147483647)
        XCTAssertEqual(Stride.milliseconds(.max).timeInterval, 2147483.647)
        XCTAssertEqual(Stride.microseconds(.max).timeInterval, 2147.483647)
        XCTAssertEqual(Stride.nanoseconds(.max).timeInterval, 2.147483647)
#else
#error("This architecture isn't known. Add it to the 32-bit or 64-bit line.")
#endif
    }

    func testStrideFromTimeInterval() {
        RunLoopSchedulerTests.testStrideFromTimeInterval(RunLoopScheduler.self)
    }

    static func testStrideFromTimeInterval<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        typealias Stride = Context.SchedulerTimeType.Stride
        XCTAssertEqual(Stride(2).magnitude, 2)
        XCTAssertEqual(Stride(2.2).magnitude, 2.2)
        XCTAssertEqual(Stride(.infinity).magnitude, .infinity)
        XCTAssertEqual(Stride(0.002).magnitude, 0.002)
        XCTAssertEqual(Stride(2E-06).magnitude, 2E-06)
        XCTAssertEqual(Stride(2E-09).magnitude, 2E-09)
        XCTAssertEqual(Stride(9.223372036854776E+18).magnitude, 9.223372036854776E+18)
    }

    func testStrideFromNumericValue() {
        RunLoopSchedulerTests.testStrideFromNumericValue(RunLoopScheduler.self)
    }

    static func testStrideFromNumericValue<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        typealias Stride = Context.SchedulerTimeType.Stride

        XCTAssertEqual((1.2 as Stride).magnitude, 1.2)
        XCTAssertEqual((2 as Stride).magnitude, 2)

        XCTAssertNil(Stride(exactly: UInt64.max))
        XCTAssertEqual(Stride(exactly: 871 as UInt64)?.magnitude, 871)
    }

    func testStrideComparable() {
        RunLoopSchedulerTests.testStrideComparable(RunLoopScheduler.self)
    }

    static func testStrideComparable<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        typealias Stride = Context.SchedulerTimeType.Stride
        XCTAssertLessThan(Stride.nanoseconds(1), .nanoseconds(2))
        XCTAssertGreaterThan(Stride.nanoseconds(-2), .microseconds(-10))
        XCTAssertLessThan(Stride.milliseconds(2), .seconds(2))
    }

    func testStrideMultiplication() {
        RunLoopSchedulerTests.testStrideMultiplication(RunLoopScheduler.self)
    }

    static func testStrideMultiplication<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        typealias Stride = Context.SchedulerTimeType.Stride

        XCTAssertEqual((Stride.nanoseconds(0) * .nanoseconds(61346)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(61346) * .nanoseconds(0)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(18) * .nanoseconds(1)).magnitude, 1.8E-17)
        XCTAssertEqual((Stride.nanoseconds(18) * .microseconds(1)).magnitude, 1.8E-14)
        XCTAssertEqual((Stride.nanoseconds(1) * .nanoseconds(18)).magnitude, 1.8E-17)
        XCTAssertEqual((Stride.microseconds(1) * .nanoseconds(18)).magnitude, 1.8E-14)
        XCTAssertEqual((Stride.nanoseconds(15) * .nanoseconds(2)).magnitude, 3E-17)
        XCTAssertEqual((Stride.microseconds(-3) * .nanoseconds(10)).magnitude, -3E-14)

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
            XCTAssertEqual(stride.magnitude, 1.8E-17)
        }

        do {
            var stride = Stride.nanoseconds(18)
            stride *= .microseconds(1)
            XCTAssertEqual(stride.magnitude, 1.8E-14)
        }

        do {
            var stride = Stride.nanoseconds(1)
            stride *= .nanoseconds(18)
            XCTAssertEqual(stride.magnitude, 1.8E-17)
        }

        do {
            var stride = Stride.microseconds(1)
            stride *= .nanoseconds(18)
            XCTAssertEqual(stride.magnitude, 1.8E-14)
        }

        do {
            var stride = Stride.nanoseconds(15)
            stride *= .nanoseconds(2)
            XCTAssertEqual(stride.magnitude, 3E-17)
        }

        do {
            var stride = Stride.microseconds(-3)
            stride *= .nanoseconds(10)
            XCTAssertEqual(stride.magnitude, -3E-14)
        }
    }

    func testStrideAddition() {
        RunLoopSchedulerTests.testStrideAddition(RunLoopScheduler.self)
    }

    static func testStrideAddition<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        typealias Stride = Context.SchedulerTimeType.Stride

        XCTAssertEqual((Stride.nanoseconds(0) + .microseconds(2)).magnitude, 2E-06)
        XCTAssertEqual((Stride.nanoseconds(2) + .microseconds(0)).magnitude, 2E-09)
        XCTAssertEqual((Stride.nanoseconds(7) + .nanoseconds(12)).magnitude,
                       1.8999999999999998E-08)
        XCTAssertEqual((Stride.nanoseconds(12) + .nanoseconds(7)).magnitude,
                       1.8999999999999998E-08)
        XCTAssertEqual((Stride.nanoseconds(7) + .nanoseconds(-12)).magnitude, -5E-09)
        XCTAssertEqual((Stride.nanoseconds(-12) + .nanoseconds(7)).magnitude, -5E-09)
        XCTAssertEqual((Stride.milliseconds(-12) + .seconds(7)).magnitude, 6.988)
        XCTAssertEqual((Stride.seconds(-12) + .milliseconds(7)).magnitude, -11.993)

        do {
            var stride = Stride.nanoseconds(0)
            stride += .microseconds(2)
            XCTAssertEqual(stride.magnitude, 2E-06)
        }

        do {
            var stride = Stride.nanoseconds(2)
            stride += .microseconds(0)
            XCTAssertEqual(stride.magnitude, 2E-09)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride += .nanoseconds(12)
            XCTAssertEqual(stride.magnitude, 1.8999999999999998E-08)
        }

        do {
            var stride = Stride.nanoseconds(12)
            stride += .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, 1.8999999999999998E-08)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride += .nanoseconds(-12)
            XCTAssertEqual(stride.magnitude, -5E-09)
        }

        do {
            var stride = Stride.nanoseconds(-12)
            stride += .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, -5E-09)
        }

        do {
            var stride = Stride.seconds(-12)
            stride += .milliseconds(7)
            XCTAssertEqual(stride.magnitude, -11.993)
        }

        do {
            var stride = Stride.milliseconds(-12)
            stride += .seconds(7)
            XCTAssertEqual(stride.magnitude, 6.988)
        }
    }

    func testStrideSubtraction() {
        RunLoopSchedulerTests.testStrideSubtraction(RunLoopScheduler.self)
    }

    static func testStrideSubtraction<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) {
        typealias Stride = Context.SchedulerTimeType.Stride

        XCTAssertEqual((Stride.nanoseconds(0) - .microseconds(2)).magnitude, -2E-06)
        XCTAssertEqual((Stride.nanoseconds(2) - .microseconds(0)).magnitude, 2E-09)
        XCTAssertEqual((Stride.nanoseconds(7) - .nanoseconds(12)).magnitude, -5E-09)
        XCTAssertEqual((Stride.nanoseconds(12) - .nanoseconds(7)).magnitude, 5E-09)
        XCTAssertEqual((Stride.nanoseconds(7) - .nanoseconds(-12)).magnitude,
                       1.8999999999999998E-08)
        XCTAssertEqual((Stride.nanoseconds(-12) - .nanoseconds(7)).magnitude,
                       -1.8999999999999998E-08)
        XCTAssertEqual((Stride.seconds(-12) - .milliseconds(7)).magnitude, -12.007)
        XCTAssertEqual((Stride.milliseconds(-12) - .seconds(7)).magnitude, -7.012)

        do {
            var stride = Stride.nanoseconds(0)
            stride -= .microseconds(2)
            XCTAssertEqual(stride.magnitude, -2E-06)
        }

        do {
            var stride = Stride.nanoseconds(2)
            stride -= .microseconds(0)
            XCTAssertEqual(stride.magnitude, 2E-09)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride -= .nanoseconds(12)
            XCTAssertEqual(stride.magnitude, -5E-09)
        }

        do {
            var stride = Stride.nanoseconds(12)
            stride -= .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, 5E-09)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride -= .nanoseconds(-12)
            XCTAssertEqual(stride.magnitude, 1.8999999999999998E-08)
        }

        do {
            var stride = Stride.nanoseconds(-12)
            stride -= .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, -1.8999999999999998E-08)
        }

        do {
            var stride = Stride.seconds(-12)
            stride -= .milliseconds(7)
            XCTAssertEqual(stride.magnitude, -12.007)
        }

        do {
            var stride = Stride.milliseconds(-12)
            stride -= .seconds(7)
            XCTAssertEqual(stride.magnitude, -7.012)
        }
    }

    func testStrideCodable() throws {
        try RunLoopSchedulerTests.testStrideCodable(RunLoopScheduler.self)
    }

    static func testStrideCodable<Context: RunLoopLikeScheduler>(
        _ schedulerType: Context.Type
    ) throws {
        typealias Stride = Context.SchedulerTimeType.Stride

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let stride = Stride.seconds(1024.5)
        let encodedData = try encoder.encode(stride)
        let encodedString = String(decoding: encodedData, as: UTF8.self)

        XCTAssertEqual(encodedString, #"{"magnitude":1024.5}"#)

        let decodedStride = try decoder
            .decode(Stride.self, from: encodedData)

        XCTAssertEqual(decodedStride, stride)
    }

    // MARK: - Scheduler

    func testScheduleActionOnceNow() {
        let mainRunLoop = RunLoop.main
        let now = Date()
        var actualDate = Date.distantPast
        executeOnBackgroundThread {
            makeScheduler(mainRunLoop).schedule {
                XCTAssertTrue(Thread.isMainThread)
                actualDate = Date()
                RunLoop.current.run(until: Date() + 0.01)
            }
        }
        XCTAssertEqual(actualDate, .distantPast)
        mainRunLoop.run(until: Date() + 0.05)
        XCTAssertEqual(actualDate.timeIntervalSinceReferenceDate,
                       now.timeIntervalSinceReferenceDate,
                       accuracy: 0.1)
    }

    func testScheduleActionOnceLater() {
        let mainRunLoop = RunLoop.main
        let now = Date()
        var actualDate = Date.distantPast
        let desiredDelay: TimeInterval = 0.6
        executeOnBackgroundThread {
            let scheduler = makeScheduler(mainRunLoop)
            scheduler
                .schedule(after: scheduler.now.advanced(by: .init(desiredDelay))) {
                    XCTAssertTrue(Thread.isMainThread)
                    actualDate = Date()
                }
        }

        mainRunLoop.run(until: Date() + 1)

        XCTAssertEqual(
            actualDate.timeIntervalSinceReferenceDate -
                now.timeIntervalSinceReferenceDate,
            desiredDelay,
            accuracy: desiredDelay / 3
        )
    }

    func testScheduleRepeating() {
        let mainRunLoop = RunLoop.main

        let expectation10ticks = expectation(description: "10 ticks")
        expectation10ticks.expectedFulfillmentCount = 10

        let startDate = Date().timeIntervalSinceReferenceDate

        let ticks = Atomic([TimeInterval]())

        let desiredDelay: TimeInterval = 0.7
        let desiredInterval: TimeInterval = 0.3

        let cancellable = executeOnBackgroundThread { () -> Cancellable in
            let scheduler = makeScheduler(mainRunLoop)
            return scheduler
                .schedule(after: scheduler.now.advanced(by: .init(desiredDelay)),
                          interval: .init(desiredInterval)) {
                    XCTAssertTrue(Thread.isMainThread)
                    ticks.do {
                        $0.append(Date().timeIntervalSinceReferenceDate)
                    }
                    expectation10ticks.fulfill()
                    RunLoop.current.run(until: Date() + 0.001)
                }
        }

        XCTAssertEqual(ticks.value.count, 0)
        mainRunLoop.run(until: Date() + 0.001)
        XCTAssertEqual(ticks.value.count, 0)

        wait(for: [expectation10ticks], timeout: 5)

        if ticks.value.isEmpty {
            XCTFail("The scheduler doesn't work")
            return
        }

        let actualDelay = ticks.value[0] - startDate
        let actualIntervals = zip(ticks.value.dropFirst(), ticks.value.dropLast()).map(-)
        let averageInterval = actualIntervals.reduce(0, +) / Double(actualIntervals.count)

        XCTAssertEqual(actualDelay,
                       desiredDelay,
                       accuracy: desiredDelay / 3,
                       """
                       Actual delay (\(actualDelay)) deviates from desired delay \
                       (\(desiredDelay)) too much
                       """)

        XCTAssertEqual(averageInterval,
                       desiredInterval,
                       accuracy: desiredInterval / 3,
                       """
                       Actual average interval (\(averageInterval)) deviates from \
                       desired interval (\(desiredInterval)) too much.

                       Actual intervals: \(actualIntervals)
                       """)

        cancellable.cancel()
        let numberOfTicksRightAfterCancellation = ticks.value.count
        mainRunLoop.run(until: Date() + 1)
        let numberOfTicksOneSecondAfterCancellation = ticks.value.count
        XCTAssertEqual(numberOfTicksRightAfterCancellation,
                       numberOfTicksOneSecondAfterCancellation)
    }

    func testMinimumTolerance() {
        let scheduler = makeScheduler(.main)
        XCTAssertEqual(scheduler.minimumTolerance, .init(0))
    }

    func testNow() {
        let scheduler = makeScheduler(.main)
        XCTAssertEqual(scheduler.now.date.timeIntervalSinceReferenceDate,
                       Date().timeIntervalSinceReferenceDate,
                       accuracy: 0.001)
    }
}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)

private typealias RunLoopScheduler = RunLoop

private func makeScheduler(_ runLoop: RunLoop) -> RunLoopScheduler {
    return runLoop
}

#else

private typealias RunLoopScheduler = RunLoop.OCombine

private func makeScheduler(_ runLoop: RunLoop) -> RunLoopScheduler {
    return runLoop.ocombine
}

#endif

protocol DateBackedSchedulerTimeType: Strideable, Codable, Hashable {
    init(_ date: Date)

    var date: Date { get }
}

protocol TimeIntervalBackedSchedulerStride: SchedulerTimeIntervalConvertible,
                                            Comparable,
                                            SignedNumeric,
                                            ExpressibleByFloatLiteral,
                                            Codable
    where Magnitude == TimeInterval
{
    init(_ timeInterval: TimeInterval)

    var timeInterval: TimeInterval { get }
}

protocol RunLoopLikeScheduler: Scheduler
    where SchedulerTimeType: DateBackedSchedulerTimeType,
          SchedulerTimeType.Stride: TimeIntervalBackedSchedulerStride {
}

@available(macOS 10.15, iOS 13.0, *)
extension RunLoopScheduler.SchedulerTimeType.Stride: TimeIntervalBackedSchedulerStride {}

@available(macOS 10.15, iOS 13.0, *)
extension RunLoopScheduler.SchedulerTimeType: DateBackedSchedulerTimeType {}

extension RunLoopScheduler: RunLoopLikeScheduler {}
