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
    }

    // MARK: -

    func testTestSuiteIncludesAllTests() {
    }
}
