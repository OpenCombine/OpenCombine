//
//  ScanTests.swift
//
//
//  Created by Eric Patey on 27.08.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ScanTests: XCTestCase {
    static let allTests = [
        ("testSimpleScan", testSimpleScan),
        ("testSimpleTryScan", testSimpleTryScan),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    func testSimpleScan() {
        let publisher = PassthroughSubject<Int, TestingError>()
        let scan = publisher.scan(0) { $0 + $1 }

        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        scan.subscribe(tracking)
        publisher.send(0)
        publisher.send(1)
        publisher.send(2)
        publisher.send(3)
        publisher.send(4)
        publisher.send(5)

        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject"),
                                          .value(0),
                                          .value(1),
                                          .value(3),
                                          .value(6),
                                          .value(10),
                                          .value(15)])
    }

    func testSimpleTryScan() {
        let publisher = PassthroughSubject<Int, TestingError>()
        let scan = publisher.tryScan(0) { $0 + $1 }

        let tracking = TrackingSubscriberBase<Int, Error>(receiveSubscription: {
            $0.request(.unlimited) })

        scan.subscribe(tracking)
        publisher.send(0)
        publisher.send(1)
        publisher.send(2)
        publisher.send(3)
        publisher.send(4)
        publisher.send(5)

        XCTAssertEqual(tracking.history, [.subscription("TryScan"),
                                          .value(0),
                                          .value(1),
                                          .value(3),
                                          .value(6),
                                          .value(10),
                                          .value(15)])
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
