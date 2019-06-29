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
        ("testTryFilterWorks", testTryFilterWorks),
        ("testTryFilterCanFilterOtherFilter", testTryFilterCanFilterOtherFilter)
    ]

    func testFilterRemovesElements() {
        var results: [Int] = []

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        _ = publisher.filter {
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
        _ = publisher.filter {
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
        _ = publisher.tryFilter {
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
        _ = publisher.tryFilter {
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

    func testTryFilterCompletesWithErrorWhenThrown() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        var error: TestingError?
        _ = publisher.tryFilter {
            try failOnFive(value: $0)
        }.sink(receiveCompletion: { completion in
                if case let .failure(completionError) = completion {
                    error = completionError as? TestingError
                }
        }, receiveValue: { _ in })
        for i in 1...5 {
            _ = publisher.send(i)
        }
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .canceled])
        XCTAssertEqual(error, TestingError.oops)
    }
}

private func nonthrowingReturn(_ value: Int) throws -> Bool {
    return true
}

private func failOnFive(value: Int) throws -> Bool {
    if value == 5 {
        throw TestingError.oops
    }
    return true
}
