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

    func testFilterRemovesElements() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(2),
                                        receiveValueDemand: .none) {
            $0.filter { $0.isMultiple(of: 2) }
        }

        // When
        for i in 1...5 {
            XCTAssertEqual(helper.publisher.send(i),
                           helper.sut.isIncluded(i) ? .none : .max(1))
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"),
                                                 .value(2),
                                                 .value(4)])
    }

    func testTryFilterWorks() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(2),
                                        receiveValueDemand: .none) {
            $0.tryFilter {
                try $0.isMultiple(of: 2) && nonthrowingReturn($0)
            }
        }

        // When
        for i in 1...5 {
            XCTAssertEqual(helper.publisher.send(i),
                           try helper.sut.isIncluded(i) ? .none : .max(1))
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"),
                                                 .value(2),
                                                 .value(4)])
    }

    func testTryFilterCompletesWithErrorWhenThrown() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.tryFilter {
                try failOnFive(value: $0)
            }
        }

        // When
        for i in 1...5 {
            _ = helper.publisher.send(i)
        }

        helper.publisher.send(completion: .finished)

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
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.filter { _ in true }
        }

        // When
        XCTAssertEqual(helper.publisher.send(1), .none)
        helper.publisher.send(completion: .finished)

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"),
                                                 .value(1),
                                                 .completion(.finished)])
    }

    func testFilterCanCompleteWithError() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.filter { _ in true }
        }

        // When
        XCTAssertEqual(helper.publisher.send(1), .none)
        helper.publisher.send(completion: .failure(.oops))

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"),
                                                 .value(1),
                                                 .completion(.failure(.oops))])
    }

    func testTryFilterCanCompleteWithError() {
        // Given
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: {
                $0.tryFilter { _ in true }
            }
        )

        // When
        XCTAssertEqual(helper.publisher.send(1), .none)
        helper.publisher.send(completion: .failure(.oops))

        // Then
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryFilter"),
                        .value(1),
                        .completion(.failure(TestingError.oops))])
    }

    func testFilterSubscriptionDemand() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(3),
            receiveValueDemand: .none,
            createSut: {
                $0.filter { $0.isMultiple(of: 2) }
            }
        )

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
                                        initialDemand: .max(3),
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

    func testFilterCancel() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.filter { $0.isMultiple(of: 2) } })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send(2), .none)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(4), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter")])
    }

    func testTryFilterCancel() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: {
                $0.tryFilter { try failOnFive(value: $0) && $0.isMultiple(of: 2) }
            }
        )

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send(2), .none)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(5), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter")])
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.filter { $0.isMultiple(of: 2) } })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = { deinitCounter += 1 }

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let filter = passthrough.filter { $0.isMultiple(of: 2) }
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            filter.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        XCTAssertEqual(deinitCounter, 0)

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let filter = passthrough.filter { $0.isMultiple(of: 2) }
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            filter.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 0)

        var subscription: Subscription?

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let filter = passthrough.filter { $0.isMultiple(of: 2) }
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            filter.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(32)
            XCTAssertEqual(emptySubscriber.inputs.count, 1)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 0)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 0)
    }

    func testFilterOperatorSpecializationForFilter() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none) {
            $0.filter {
                $0.isMultiple(of: 3)
            }.filter {
                $0.isMultiple(of: 5)
            }
        }

        // When
        for i in 1...20 {
            XCTAssertEqual(helper.publisher.send(i),
                           helper.sut.isIncluded(i) ? .none : .max(1))
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("Filter"), .value(15)])
    }

    func testTryFilterOperatorSpecializationForFilter() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none) {
            $0.filter {
                $0.isMultiple(of: 3)
            }.tryFilter {
                $0.isMultiple(of: 5)
            }
        }

        // When
        for i in 1...20 {
            XCTAssertEqual(helper.publisher.send(i),
                           try helper.sut.isIncluded(i) ? .none : .max(1))
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"), .value(15)])
    }

    func testFilterOperatorSpecializationForTryFilter() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none) {
            $0.tryFilter {
                $0.isMultiple(of: 3)
            }.filter {
                $0.isMultiple(of: 5)
            }
        }

        // When
        for i in 1...20 {
            XCTAssertEqual(helper.publisher.send(i),
                           try helper.sut.isIncluded(i) ? .none : .max(1))
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"), .value(15)])
    }

    func testTryFilterOperatorSpecializationForTryFilter() {
        // Given
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(3),
                                        receiveValueDemand: .none) {
            $0.tryFilter {
                $0.isMultiple(of: 3)
            }.tryFilter {
                $0.isMultiple(of: 5)
            }
        }

        // When
        for i in 1...20 {
            XCTAssertEqual(helper.publisher.send(i),
                           try helper.sut.isIncluded(i) ? .none : .max(1))
        }

        // Then
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"),
                                                 .value(15)])
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
