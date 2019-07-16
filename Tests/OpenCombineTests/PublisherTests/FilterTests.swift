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

@available(macOS 10.15, iOS 13.0, *)
final class FilterTests: XCTestCase {
    static let allTests = [
        ("testFilterRemovesElements", testFilterRemovesElements),
        ("testFilteringOtherFilters", testFilteringOtherFilters),
        ("testTryFilterWorks", testTryFilterWorks),
        ("testTryFilterCanFilterOtherFilter", testTryFilterCanFilterOtherFilter),
        ("testTryFilterCompletesWithErrorWhenThrown",
            testTryFilterCompletesWithErrorWhenThrown),
        ("testFilterSubscriptionDemand", testFilterSubscriptionDemand),
        ("testTryFilterSubscriptionDemand", testTryFilterSubscriptionDemand)
    ]

    func testFilterRemovesElements() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self) {
            $0.filter { $0.isMultiple(of: 2) }
        }

        // When
        for i in 1...5 {
            _ = helper.publisher.send(i)
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"),
                                                 .value(2),
                                                 .value(4)])
    }

    func testFilteringOtherFilters() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self) {
            $0.filter {
                $0.isMultiple(of: 3)
            }.filter {
                $0.isMultiple(of: 5)
            }
        }

        // When
        for i in 1...15 {
            _ = helper.publisher.send(i)
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"), .value(15)])
    }

    func testTryFilterWorks() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self) {
            $0.tryFilter {
                try $0.isMultiple(of: 2) && nonthrowingReturn($0)
            }
        }

        // When
        for i in 1...5 {
            _ = helper.publisher.send(i)
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"),
                                                 .value(2),
                                                 .value(4)])
    }

    func testTryFilterCanFilterOtherFilter() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self) {
            $0.tryFilter {
                $0.isMultiple(of: 3)
            }.tryFilter {
                try nonthrowingReturn($0)
            }
        }

        // When
        for i in 1...9 {
            _ = helper.publisher.send(i)
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"),
                                                 .value(3),
                                                 .value(6),
                                                 .value(9)])
    }

    func testTryFilterCompletesWithErrorWhenThrown() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self) {
            $0.tryFilter {
                try failOnFive(value: $0)
            }
        }

        // When
        for i in 1...5 {
            _ = helper.publisher.send(i)
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4),
                                                 .completion(.failure(TestingError.oops))
        ])
    }

    func testCanCompleteWithFinished() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self) {
            $0.filter { _ in true }
        }

        // When
        _ = helper.publisher.send(1)
        helper.publisher.send(completion: .finished)

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"),
                                                 .value(1),
                                                 .completion(.finished)])
    }

    func testCanCompleteWithError() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self) {
            $0.filter { _ in true }
        }

        // When
        _ = helper.publisher.send(1)
        helper.publisher.send(completion: .failure(.oops))

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"),
                                                 .value(1),
                                                 .completion(.failure(.oops))])
    }

    func testFilterSubscriptionDemand() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        trackingDemand: .max(3),
                                        receiveValueDemand: .none) {
                                            $0.filter { $0.isMultiple(of: 2) }
        }

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(0))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(0))
        XCTAssertEqual(helper.publisher.send(5), .max(1))
        XCTAssertEqual(helper.publisher.send(6), .max(0))
        XCTAssertEqual(helper.publisher.send(7), .max(1))
        XCTAssertEqual(helper.publisher.send(8), .max(0))

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
    }

    func testTryFilterSubscriptionDemand() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        trackingDemand: .max(3),
                                        receiveValueDemand: .none) {
                                            $0.tryFilter { $0.isMultiple(of: 2) }
        }

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(0))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(0))
        XCTAssertEqual(helper.publisher.send(5), .max(1))
        XCTAssertEqual(helper.publisher.send(6), .max(0))
        XCTAssertEqual(helper.publisher.send(7), .max(1))
        XCTAssertEqual(helper.publisher.send(8), .max(0))
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
