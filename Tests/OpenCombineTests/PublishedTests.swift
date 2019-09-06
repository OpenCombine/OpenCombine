//
//  PublishedTests.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 06/09/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class PublishedTests: XCTestCase {

    static let allTests = [
        ("testPublisher", testPublisher),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    func testPublisher() {
        #if OPENCOMBINE_COMPATIBILITY_TEST
        var published: OpenCombine.Published<Int> = Published(initialValue: 0)
        // All tests for CurrentValueSubject already exists
        XCTAssert(publisher is CurrentValueSubject)
        #endif
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
