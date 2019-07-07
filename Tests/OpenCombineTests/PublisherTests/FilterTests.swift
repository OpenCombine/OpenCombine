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
        let helper = TestHelper(publisherType: CustomPublisher.self) {
            $0.filter { $0.isMultiple(of: 2) }
        }

        for i in 1...5 {
            _ = helper.publisher.send(i)
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"),
                                                 .value(2),
                                                 .value(4)])
    }

    func testFilteringOtherFilters() {
        let helper = TestHelper(publisherType: CustomPublisher.self) {
            $0.filter {
                $0.isMultiple(of: 3)
            }.filter {
                $0.isMultiple(of: 5)
            }
        }

        for i in 1...15 {
            _ = helper.publisher.send(i)
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"), .value(15)])
    }

    func testTryFilterWorks() {
        let helper = TestHelper(publisherType: CustomPublisher.self) {
            $0.tryFilter {
                try $0.isMultiple(of: 2) && nonthrowingReturn($0)
            }
        }

        for i in 1...5 {
            _ = helper.publisher.send(i)
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"),
                                                 .value(2),
                                                 .value(4)])
    }

    func testTryFilterCanFilterOtherFilter() {
        let helper = TestHelper(publisherType: CustomPublisher.self) {
            $0.tryFilter {
                $0.isMultiple(of: 3)
            }.tryFilter {
                try nonthrowingReturn($0)
            }
        }

        for i in 1...9 {
            _ = helper.publisher.send(i)
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"),
                                                 .value(3),
                                                 .value(6),
                                                 .value(9)])
    }

    func testTryFilterCompletesWithErrorWhenThrown() {
        let helper = TestHelper(publisherType: CustomPublisher.self) {
            $0.tryFilter {
                try failOnFive(value: $0)
            }
        }

        for i in 1...5 {
            _ = helper.publisher.send(i)
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4),
                                                 .completion(.failure(TestingError.oops))
        ])
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
