//
//  FilterTests.swift
//  
//
//  Created by Joseph Spadafora on 6/25/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
@testable
import OpenCombine
#endif

@available(macOS 10.15, *)
final class FilterTests: XCTestCase {
    static let allTests = [
        ("testFilterRemovesElements", testFilterRemovesElements),
        ("testFilteringOtherFilters", testFilteringOtherFilters)
    ]
    
    func testFilterRemovesElements() {
        var results: [Int] = []
        
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        _ = Publishers.Filter(upstream: publisher) {
            $0 % 2 == 0
        }.sink {
            results.append($0)
        }
        for i in 1...5 {
            _ = publisher.send(i)
        }
        
        XCTAssertEqual(results, [2, 4])
    }
    
    func testFilteringOtherFilters() {
        var results: [Int] = []
        
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        _ = Publishers.Filter(upstream: publisher) {
            $0 % 3 == 0
        }.filter {
            $0 % 5 == 0
        }.sink {
            results.append($0)
        }
        for i in 1...15 {
            _ = publisher.send(i)
        }
        
        XCTAssertEqual(results, [15])
    }
}
