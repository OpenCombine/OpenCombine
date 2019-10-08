//
//  FirstTests.swift
//  
//
//  Created by Joseph Spadafora on 7/9/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class FirstTests: XCTestCase {

    func testFirstDemand() throws {

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.first() })

        XCTAssertEqual(helper.tracking.history, [.subscription("First")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("First")])

        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .value(1),
                                                 .completion(.finished)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testFirstFinishesAndReturnsFirstItem() {

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(3),
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.first() })

        XCTAssertEqual(helper.tracking.history, [.subscription("First")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(25), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .value(25),
                                                 .completion(.finished)])

        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .value(25),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(73), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .value(25),
                                                 .completion(.finished)])
    }

    func testFirstFinishesWithError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(3),
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.first() })

        XCTAssertEqual(helper.tracking.history, [.subscription("First")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(73), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testFirstFinishesImmediately() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(3),
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.first() })

        XCTAssertEqual(helper.tracking.history, [.subscription("First")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(73), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("First"),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testFirstLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.first() })
    }

    func testFirstWhereDemand() throws {

        var firedCounter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: {
                $0.first {
                    firedCounter += 1
                    return $0 > 1
                }
            }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst")])
        XCTAssertEqual(firedCounter, 3)

        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst"),
                                                 .value(2),
                                                 .completion(.finished)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testFirstWhereFinishesAndReturnsFirstMatchingItem() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(5),
            receiveValueDemand: .max(1),
            createSut: { $0.first(where: { $0 > 2 }) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst")])

        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst")])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst"),
                                                 .value(3),
                                                 .completion(.finished)])

        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst"),
                                                 .value(3),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst"),
                                                 .value(3),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testFirstWhereFinishesWithError() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(5),
            receiveValueDemand: .max(1),
            createSut: { $0.first(where: { $0 > 2 }) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(73), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirst"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testFirstWhereLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.first { $0 > 1 } })
    }

    func testTryFirstWhereDemand() throws {

        var firedCounter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: {
                $0.tryFirst {
                    firedCounter += 1
                    return $0 > 1
                }
            }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(firedCounter, 3)

        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere"),
                                                 .value(2),
                                                 .completion(.finished)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testTryFirstWhereReturnsFirstMatchingElement() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(5),
            receiveValueDemand: .max(1),
            createSut: { $0.tryFirst(where: { $0 > 6 }) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        for number in 1...6 {
            XCTAssertEqual(helper.publisher.send(number), .none)
            XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere")])
        }

        XCTAssertEqual(helper.publisher.send(7), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere"),
                                                 .value(7),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.publisher.send(8), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere"),
                                                 .value(7),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testTryFirstWhereFinishesWithError() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(5),
            receiveValueDemand: .max(1),
            createSut: { $0.tryFirst(where: { $0 > 6 }) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryFirstWhere"),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryFirstWhere"),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(73), .none)
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryFirstWhere"),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testTryFirstWhereFinishesWhenErrorThrown() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(5),
            receiveValueDemand: .max(1),
            createSut: {
                $0.tryFirst(where: {
                    if $0 == 3 {
                        throw TestingError.oops
                    }
                    return $0 > 3
                })
            }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryFirstWhere"),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryFirstWhere"),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testTryFirstWhereLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryFirst { $0 > 1 } })
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.first() })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }
}
