//
//  FailTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 19.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class FailTests: XCTestCase {

    static let allTests = [
        ("testSubscription", testSubscription),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    private typealias Sut = Fail<Int, TestingError>

    func testSubscription() {
        let just = Sut(error: .oops)
        let tracking = TrackingSubscriber()
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Empty"),
                                          .completion(.failure(.oops))])
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
