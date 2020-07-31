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
        let distantFuture = Scheduler.SchedulerTimeType(.distantFuture)
        let notSoDistantFuture = Scheduler.SchedulerTimeType(
            DispatchTime(
                uptimeNanoseconds: DispatchTime.distantFuture.uptimeNanoseconds - 1024
            )
        )

        XCTAssertEqual(time1.distance(to: time2), .nanoseconds(431))
        XCTAssertEqual(time2.distance(to: time1), .nanoseconds(-431))

        XCTAssertEqual(time1.distance(to: distantFuture), .nanoseconds(-10001))
        XCTAssertEqual(distantFuture.distance(to: time1), .nanoseconds(10001))
        XCTAssertEqual(time2.distance(to: distantFuture), .nanoseconds(-10432))
        XCTAssertEqual(distantFuture.distance(to: time2), .nanoseconds(10432))

        XCTAssertEqual(time1.distance(to: notSoDistantFuture), .nanoseconds(-11025))
        XCTAssertEqual(notSoDistantFuture.distance(to: time1), .nanoseconds(11025))
        XCTAssertEqual(time2.distance(to: notSoDistantFuture), .nanoseconds(-11456))
        XCTAssertEqual(notSoDistantFuture.distance(to: time2), .nanoseconds(11456))

        XCTAssertEqual(distantFuture.distance(to: distantFuture), .nanoseconds(0))
        XCTAssertEqual(notSoDistantFuture.distance(to: notSoDistantFuture),
                       .nanoseconds(0))
    }

    func testSchedulerTimeTypeAdvanced() {
        let time = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10000))
        let beginningOfTime = Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 1))
        let stride1 = Scheduler.SchedulerTimeType.Stride.nanoseconds(431)
        let stride2 = Scheduler.SchedulerTimeType.Stride.nanoseconds(-220)

        XCTAssertEqual(time.advanced(by: stride1),
                       Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 10431)))

        XCTAssertEqual(time.advanced(by: stride2),
                       Scheduler.SchedulerTimeType(.init(uptimeNanoseconds: 9780)))

        XCTAssertEqual(time.advanced(by: .nanoseconds(.max)).dispatchTime,
                       .distantFuture)

        XCTAssertEqual(beginningOfTime.advanced(by: .nanoseconds(-1000)).dispatchTime,
                       DispatchTime(uptimeNanoseconds: 1))
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
        XCTAssertNotEqual(time3, time1)
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
        switch (Stride.seconds(2).timeInterval,
                Stride.milliseconds(2).timeInterval,
                Stride.microseconds(2).timeInterval,
                Stride.nanoseconds(2).timeInterval,
                Stride.nanoseconds(.max).timeInterval) {
        case (.nanoseconds(2_000_000_000),
              .nanoseconds(2_000_000),
              .nanoseconds(2_000),
              .nanoseconds(2),
              .nanoseconds(.max)):
            break // pass
        case let intervals:
            XCTFail("Unexpected DispatchTimeInterval: \(intervals)")
        }
    }

    func testStrideFromDispatchTimeInterval() throws {
        XCTAssertEqual(Stride(.seconds(2)).magnitude, 2_000_000_000)
        XCTAssertEqual(Stride(.milliseconds(2)).magnitude, 2_000_000)
        XCTAssertEqual(Stride(.microseconds(2)).magnitude, 2_000)
        XCTAssertEqual(Stride(.nanoseconds(2)).magnitude, 2)

        XCTAssertEqual(Stride(.never).magnitude, .max)
        XCTAssertEqual(Stride(.nanoseconds(.max)).magnitude, .max)
        XCTAssertEqual(Stride(.nanoseconds(.min)).magnitude, .min)
        XCTAssertEqual(Stride(.microseconds(.max)).magnitude, .max)
        XCTAssertEqual(Stride(.microseconds(.min)).magnitude, .min)
        XCTAssertEqual(Stride(.milliseconds(.max)).magnitude, .max)
        XCTAssertEqual(Stride(.milliseconds(.min)).magnitude, .min)
        XCTAssertEqual(Stride(.seconds(.max)).magnitude, .max)
        XCTAssertEqual(Stride(.seconds(.min)).magnitude, .min)
    }

    func testStrideFromUnknownDispatchTimeIntervalCase() {
        // Here we're testing out internal API that is not present in Combine.
        // Although we prefer only testing public APIs, this case is special.
        let makeStride: (DispatchTimeInterval) -> Stride
#if OPENCOMBINE_COMPATIBILITY_TEST
        makeStride = Stride.init(_:)
#else
        makeStride = Stride.init(__guessFromUnknown:)
#endif

#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        // 64-bit platforms
        let minNanoseconds = -0x13B13B13B13B13B0 // Int64.min / 6.5
        let maxNanoseconds =  0x2C4EC4EC4EC4EC4D // Int64.max / 2.889
#elseif arch(i386) || arch(arm)
        // 32-bit platforms
        let minNanoseconds = Int.min + 1
        let maxNanoseconds = Int.max
#else
#error("This architecture isn't known. Add it to the 32-bit or 64-bit line.")
#endif
        XCTAssertEqual(makeStride(.nanoseconds(minNanoseconds)).magnitude, minNanoseconds)
        XCTAssertEqual(makeStride(.nanoseconds(-128)).magnitude, -128)
        XCTAssertEqual(makeStride(.nanoseconds(-57)).magnitude, -57)
        XCTAssertEqual(makeStride(.nanoseconds(-33)).magnitude, -33)
        XCTAssertEqual(makeStride(.nanoseconds(-17)).magnitude, -17)
        XCTAssertEqual(makeStride(.nanoseconds(-8)).magnitude, -8)
        XCTAssertEqual(makeStride(.nanoseconds(-3)).magnitude, -3)
        XCTAssertEqual(makeStride(.nanoseconds(-1)).magnitude, -1)
        XCTAssertEqual(makeStride(.nanoseconds(0)).magnitude, 0)
        XCTAssertEqual(makeStride(.nanoseconds(1)).magnitude, 1)
        XCTAssertEqual(makeStride(.nanoseconds(3)).magnitude, 3)
        XCTAssertEqual(makeStride(.nanoseconds(8)).magnitude, 8)
        XCTAssertEqual(makeStride(.nanoseconds(17)).magnitude, 17)
        XCTAssertEqual(makeStride(.nanoseconds(33)).magnitude, 33)
        XCTAssertEqual(makeStride(.nanoseconds(57)).magnitude, 57)
        XCTAssertEqual(makeStride(.nanoseconds(128)).magnitude, 128)
        XCTAssertEqual(makeStride(.nanoseconds(maxNanoseconds)).magnitude, maxNanoseconds)

        XCTAssertEqual(makeStride(.microseconds(-128)).magnitude, -128_000)
        XCTAssertEqual(makeStride(.microseconds(-57)).magnitude, -57_000)
        XCTAssertEqual(makeStride(.microseconds(-33)).magnitude, -33_000)
        XCTAssertEqual(makeStride(.microseconds(-17)).magnitude, -17_000)
        XCTAssertEqual(makeStride(.microseconds(-8)).magnitude, -8_000)
        XCTAssertEqual(makeStride(.microseconds(-3)).magnitude, -3_000)
        XCTAssertEqual(makeStride(.microseconds(-1)).magnitude, -1_000)
        XCTAssertEqual(makeStride(.microseconds(0)).magnitude, 0)
        XCTAssertEqual(makeStride(.microseconds(1)).magnitude, 1_000)
        XCTAssertEqual(makeStride(.microseconds(3)).magnitude, 3_000)
        XCTAssertEqual(makeStride(.microseconds(8)).magnitude, 8_000)
        XCTAssertEqual(makeStride(.microseconds(17)).magnitude, 17_000)
        XCTAssertEqual(makeStride(.microseconds(33)).magnitude, 33_000)
        XCTAssertEqual(makeStride(.microseconds(57)).magnitude, 57_000)
        XCTAssertEqual(makeStride(.microseconds(128)).magnitude, 128_000)

        XCTAssertEqual(makeStride(.milliseconds(-128)).magnitude, -128_000_000)
        XCTAssertEqual(makeStride(.milliseconds(-57)).magnitude, -57_000_000)
        XCTAssertEqual(makeStride(.milliseconds(-33)).magnitude, -33_000_000)
        XCTAssertEqual(makeStride(.milliseconds(-17)).magnitude, -17_000_000)
        XCTAssertEqual(makeStride(.milliseconds(-8)).magnitude, -8_000_000)
        XCTAssertEqual(makeStride(.milliseconds(-3)).magnitude, -3_000_000)
        XCTAssertEqual(makeStride(.milliseconds(-1)).magnitude, -1_000_000)
        XCTAssertEqual(makeStride(.milliseconds(0)).magnitude, 0)
        XCTAssertEqual(makeStride(.milliseconds(1)).magnitude, 1_000_000)
        XCTAssertEqual(makeStride(.milliseconds(3)).magnitude, 3_000_000)
        XCTAssertEqual(makeStride(.milliseconds(8)).magnitude, 8_000_000)
        XCTAssertEqual(makeStride(.milliseconds(17)).magnitude, 17_000_000)
        XCTAssertEqual(makeStride(.milliseconds(33)).magnitude, 33_000_000)
        XCTAssertEqual(makeStride(.milliseconds(57)).magnitude, 57_000_000)
        XCTAssertEqual(makeStride(.milliseconds(128)).magnitude, 128_000_000)

        XCTAssertEqual(makeStride(.seconds(-2)).magnitude, -2_000_000_000)
        XCTAssertEqual(makeStride(.seconds(-1)).magnitude, -1_000_000_000)
        XCTAssertEqual(makeStride(.seconds(0)).magnitude, 0)
        XCTAssertEqual(makeStride(.seconds(1)).magnitude, 1_000_000_000)
        XCTAssertEqual(makeStride(.seconds(2)).magnitude, 2_000_000_000)
    }

    func testStrideFromNumericValue() {
        XCTAssertEqual(Stride.seconds(1.2).magnitude, 1_200_000_000)
        XCTAssertEqual(Stride.seconds(2).magnitude, 2_000_000_000)
        XCTAssertEqual(Stride.milliseconds(2).magnitude, 2_000_000)
        XCTAssertEqual(Stride.microseconds(2).magnitude, 2_000)
        XCTAssertEqual(Stride.nanoseconds(2).magnitude, 2)

#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
        // 64-bit platforms
        XCTAssertEqual(
            Stride.seconds(Double(Int.max) / 1_000_000_000 - 1).magnitude,
            9223372035854776320
        )
#elseif arch(i386) || arch(arm)
        // 32-bit platforms
        XCTAssertEqual(
            Stride.seconds(Double(Int.max) / 1_000_000_000).magnitude,
            .max
        )
#else
#error("This architecture isn't known. Add it to the 32-bit or 64-bit line.")
#endif

        XCTAssertEqual(Stride.seconds(.max).magnitude, .max)
        XCTAssertEqual(Stride.milliseconds(.max).magnitude, .max)
        XCTAssertEqual(Stride.microseconds(.max).magnitude, .max)
        XCTAssertEqual(Stride.nanoseconds(.max).magnitude, .max)

        XCTAssertEqual((1.2 as Stride).magnitude, 1_200_000_000)
        XCTAssertEqual((2 as Stride).magnitude, 2_000_000_000)

        XCTAssertNil(Stride(exactly: UInt64.max))
        XCTAssertEqual(Stride(exactly: 871 as UInt64)?.magnitude, 871)
    }

    func testStrideFromTooMuchSecondsCrashes() {
        assertCrashes {
#if arch(x86_64) || arch(arm64) || arch(s390x) || arch(powerpc64) || arch(powerpc64le)
            // 64-bit platforms
            XCTAssertGreaterThan(
                Stride.seconds(Double(Int.max) / 1_000_000_000).magnitude,
                .max
            )
#elseif arch(i386) || arch(arm)
            // 32-bit platforms
            XCTAssertGreaterThan(
                Stride.seconds(Double(Int.max) / 1_000_000_000 + 1).magnitude,
                .max
            )
#else
#error("This architecture isn't known. Add it to the 32-bit or 64-bit line.")
#endif
        }
    }

    func testStrideComparable() {
        XCTAssertLessThan(Stride.nanoseconds(1), .nanoseconds(2))
        XCTAssertGreaterThan(Stride.nanoseconds(-2), .microseconds(-10))
        XCTAssertLessThan(Stride.milliseconds(2), .seconds(2))
    }

    func testStrideMultiplication() {
        XCTAssertEqual((Stride.nanoseconds(0) * .nanoseconds(61346)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(61346) * .nanoseconds(0)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(18) * .nanoseconds(1)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(18) * .microseconds(1)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(1) * .nanoseconds(18)).magnitude, 0)
        XCTAssertEqual((Stride.microseconds(1) * .nanoseconds(18)).magnitude, 0)
        XCTAssertEqual((Stride.nanoseconds(15) * .nanoseconds(2)).magnitude, 0)
        XCTAssertEqual((Stride.microseconds(-3) * .nanoseconds(10)).magnitude, 0)

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
            XCTAssertEqual(stride.magnitude, 0)
        }

        do {
            var stride = Stride.nanoseconds(18)
            stride *= .microseconds(1)
            XCTAssertEqual(stride.magnitude, 0)
        }

        do {
            var stride = Stride.nanoseconds(1)
            stride *= .nanoseconds(18)
            XCTAssertEqual(stride.magnitude, 0)
        }

        do {
            var stride = Stride.microseconds(1)
            stride *= .nanoseconds(18)
            XCTAssertEqual(stride.magnitude, 0)
        }

        do {
            var stride = Stride.nanoseconds(15)
            stride *= .nanoseconds(2)
            XCTAssertEqual(stride.magnitude, 0)
        }

        do {
            var stride = Stride.microseconds(-3)
            stride *= .nanoseconds(10)
            XCTAssertEqual(stride.magnitude, 0)
        }
    }

    func testStrideAddition() {
        XCTAssertEqual((Stride.nanoseconds(0) + .microseconds(2)).magnitude, 2000)
        XCTAssertEqual((Stride.nanoseconds(2) + .microseconds(0)).magnitude, 2)
        XCTAssertEqual((Stride.nanoseconds(7) + .nanoseconds(12)).magnitude, 19)
        XCTAssertEqual((Stride.nanoseconds(12) + .nanoseconds(7)).magnitude, 19)
        XCTAssertEqual((Stride.nanoseconds(7) + .nanoseconds(-12)).magnitude, -5)
        XCTAssertEqual((Stride.nanoseconds(-12) + .nanoseconds(7)).magnitude, -5)

        do {
            var stride = Stride.nanoseconds(0)
            stride += .microseconds(2)
            XCTAssertEqual(stride.magnitude, 2000)
        }

        do {
            var stride = Stride.nanoseconds(2)
            stride += .microseconds(0)
            XCTAssertEqual(stride.magnitude, 2)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride += .nanoseconds(12)
            XCTAssertEqual(stride.magnitude, 19)
        }

        do {
            var stride = Stride.nanoseconds(12)
            stride += .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, 19)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride += .nanoseconds(-12)
            XCTAssertEqual(stride.magnitude, -5)
        }

        do {
            var stride = Stride.nanoseconds(-12)
            stride += .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, -5)
        }
    }

    func testStrideSubtraction() {
        XCTAssertEqual((Stride.nanoseconds(0) - .microseconds(2)).magnitude, -2000)
        XCTAssertEqual((Stride.nanoseconds(2) - .microseconds(0)).magnitude, 2)
        XCTAssertEqual((Stride.nanoseconds(7) - .nanoseconds(12)).magnitude, -5)
        XCTAssertEqual((Stride.nanoseconds(12) - .nanoseconds(7)).magnitude, 5)
        XCTAssertEqual((Stride.nanoseconds(7) - .nanoseconds(-12)).magnitude, 19)
        XCTAssertEqual((Stride.nanoseconds(-12) - .nanoseconds(7)).magnitude, -19)

        do {
            var stride = Stride.nanoseconds(0)
            stride -= .microseconds(2)
            XCTAssertEqual(stride.magnitude, -2000)
        }

        do {
            var stride = Stride.nanoseconds(2)
            stride -= .microseconds(0)
            XCTAssertEqual(stride.magnitude, 2)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride -= .nanoseconds(12)
            XCTAssertEqual(stride.magnitude, -5)
        }

        do {
            var stride = Stride.nanoseconds(12)
            stride -= .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, 5)
        }

        do {
            var stride = Stride.nanoseconds(7)
            stride -= .nanoseconds(-12)
            XCTAssertEqual(stride.magnitude, 19)
        }

        do {
            var stride = Stride.nanoseconds(-12)
            stride -= .nanoseconds(7)
            XCTAssertEqual(stride.magnitude, -19)
        }
    }

    func testStrideCodable() throws {
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
                          1_000_000/*nanoseconds*/)
        XCTAssertLessThan(abs(actualNowBackgroundScheduler.distance(to: expectedNow)),
                          1_000_000/*nanoseconds*/)
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
        XCTAssertEqual(group.wait(timeout: .now() + 5.0), .success)

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

@available(macOS 10.15, iOS 13.0, *)
private typealias Stride = Scheduler.SchedulerTimeType.Stride

private struct KeyedWrapper<Value: Codable & Equatable>: Codable, Equatable {
    let value: Value
}
