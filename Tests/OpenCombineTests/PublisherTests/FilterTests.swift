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
        ("testFilteringOtherFilters", testFilteringOtherFilters),
        ("testTryFilterCanFilterOtherFilter", testTryFilterCanFilterOtherFilter)
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
    
    func testTryFilterWorks() {
        var results: [Int] = []
        
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        _ = Publishers.TryFilter(upstream: publisher) {
            try $0 % 2 == 0 && nonthrowingReturn($0)
        }.sink {
            results.append($0)
        }
        for i in 1...5 {
            _ = publisher.send(i)
        }
        
        XCTAssertEqual(results, [2, 4])
    }
    
    func testTryFilterCanFilterOtherFilter() {
        var results: [Int] = []
        
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        _ = Publishers.Filter(upstream: publisher) {
            $0 % 3 == 0
        }.tryFilter {
            try nonthrowingReturn($0)
        }.sink {
            results.append($0)
        }
        for i in 1...9 {
            _ = publisher.send(i)
        }
        
        XCTAssertEqual(results, [3, 6, 9])
    }
}

private func nonthrowingReturn(_ value: Int) throws -> Bool {
    return true
}
