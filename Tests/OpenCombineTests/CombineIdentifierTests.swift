//
//  CombineIdentifierTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 13.06.2019.
//

import GottaGoFast
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CombineIdentifierTests: PerformanceTestCase {

    static let allTests = [
        ("testDefaultInitialized", testDefaultInitialized),
        ("testAnyObject", testAnyObject),
        ("testDefaultInitializedPerformance", testDefaultInitializedPerformance),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    func testDefaultInitialized() {
        let id1 = CombineIdentifier()
        let id2 = CombineIdentifier()
        XCTAssertNotEqual(id1,
                          id2,
                          "Default-initialized Combine identifiers must be different")
    }

    func testAnyObject() {

        class Object {}

        let c1 = Object()
        let c2 = Object()

        let id1 = CombineIdentifier(c1)
        let id2 = CombineIdentifier(c2)
        let id3 = CombineIdentifier(c1)

        XCTAssertEqual(id1, id3)
        XCTAssertNotEqual(id1, id2)

        XCTAssertEqual(id1.description,
                       "0x\(String(UInt(bitPattern: ObjectIdentifier(c1)), radix: 16))")
    }

    func testDefaultInitializedPerformance() throws {
        try benchmark(allowFailure: isDebug, executionCount: 100) {
            for _ in 0..<2000 {
                _ = CombineIdentifier()
            }
        }
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
