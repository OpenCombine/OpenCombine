//
//  ImmediateSchedulerTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ImmediateSchedulerTests: XCTestCase {

    static let allTests = [
        ("testStride", testSchedulerTimeType),
        ("testActions", testActions),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    func testSchedulerTimeType() throws {

        typealias Stride = ImmediateScheduler.SchedulerTimeType.Stride

        XCTAssertEqual(ImmediateScheduler.shared.now, ImmediateScheduler.shared.now)

        let now = ImmediateScheduler.shared.now
        XCTAssertEqual(now, now.advanced(by: 100))
        XCTAssertEqual(now.distance(to: now.advanced(by: -1)), 0)

        XCTAssertEqual(Stride(14), 14)
        XCTAssertEqual(Stride(-4), -4)
        XCTAssertEqual(Stride(14), 14.6)
        XCTAssertEqual(Stride(-4), -4.1)

        XCTAssertLessThan(Stride(1), Stride(2))
        XCTAssertLessThan(Stride(-10), Stride(2))

        XCTAssertEqual(Stride(-4) * Stride(5), Stride(-20))
        XCTAssertEqual(Stride(10) * Stride(3), Stride(30))
        XCTAssertEqual(Stride(-4) + Stride(5), Stride(1))
        XCTAssertEqual(Stride(10) + Stride(3), Stride(13))
        XCTAssertEqual(Stride(-4) - Stride(5), Stride(-9))
        XCTAssertEqual(Stride(10) - Stride(3), Stride(7))

        var stride = Stride(-4)
        stride += Stride(5)
        XCTAssertEqual(stride, 1)
        stride -= Stride(-10)
        XCTAssertEqual(stride, 11)
        stride *= 2
        XCTAssertEqual(stride, 22)

        XCTAssertEqual(Stride.seconds(1.2), 0)
        XCTAssertEqual(Stride.seconds(1100), 0)
        XCTAssertEqual(Stride.milliseconds(123), 0)
        XCTAssertEqual(Stride.microseconds(51), 0)
        XCTAssertEqual(Stride.nanoseconds(23), 0)

        let encoded = try JSONEncoder().encode(["value" : Stride(-42)])
        let decoded = try JSONDecoder().decode([String : Stride].self, from: encoded)

        XCTAssertEqual(String(decoding: encoded, as: UTF8.self),
                       #"{"value":{"magnitude":-42}}"#)

        XCTAssertEqual(decoded["value"], -42)

        XCTAssertEqual(ImmediateScheduler.shared.minimumTolerance, 0)
    }

    func testActions() {

        var fired = false

        ImmediateScheduler.shared.schedule {
            fired = true
        }

        XCTAssertTrue(fired)
        fired = false

        ImmediateScheduler.shared.schedule(after: ImmediateScheduler.shared.now) {
            fired = true
        }

        XCTAssertTrue(fired)
        fired = false

        let cancellable = ImmediateScheduler
            .shared
            .schedule(after: ImmediateScheduler.shared.now, interval: 10) {
                fired = true
            }

        XCTAssertTrue(fired)
        XCTAssertEqual(String(describing: cancellable), "Empty")
    }

    // MARK: -
    func testTestSuiteIncludesAllTests() {
        // https://oleb.net/blog/2017/03/keeping-xctest-in-sync/
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let thisClass = type(of: self)
        let allTestsCount = thisClass.allTests.count
        let darwinCount = thisClass.defaultTestSuite.testCaseCount
        XCTAssertEqual(allTestsCount,
                       darwinCount,
                       "\(darwinCount - allTestsCount) tests are missing from allTests")
#endif
    }
}
