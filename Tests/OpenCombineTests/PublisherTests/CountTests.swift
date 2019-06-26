//
//  CountTests.swift
//  
//
//  Created by Joseph Spadafora on 6/25/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif


@available(macOS 10.15, *)
final class CountTests: XCTestCase {
    
    static let allTests = [
        ("testCount", testCount),
        ("testDemand", testDemand),
    ]
    
    func testCount() {
        // TODO
    }
    
    func testDemand() {
        // TODO
    }
}
