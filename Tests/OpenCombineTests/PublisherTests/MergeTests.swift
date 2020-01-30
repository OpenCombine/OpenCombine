//
//  MergeTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 06.01.2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MergeTests: XCTestCase {

    private func createTestPublishers(
        arity: Int
    ) -> ([CustomSubscription], [CustomPublisher]) {
        precondition(arity >= 0)
        let subscriptions = (0 ..< arity).map { _ in
            CustomSubscription()
        }
        let publishers = (0 ..< arity).map {
            CustomPublisher(subscription: subscriptions[$0])
        }
        return (subscriptions, publishers)
    }

    func testMergeLimitedInitialDemand() {
        func test<Merger: Publisher>(
            forArity arity: Int,
            _ makeMerger: ([CustomPublisher]) -> Merger
        ) where Merger.Output == Int, Merger.Failure == TestingError {
            let (subscriptions, publishers) = createTestPublishers(arity: arity)
            let merger = makeMerger(publishers)
            var downstreamSubscription: Subscription?
            let tracking = TrackingSubscriber(
                receiveSubscription: { downstreamSubscription = $0 },
                receiveValue: { _ in .max(3) }
            )
            merger.subscribe(tracking)

            for (i, subscription) in subscriptions.enumerated() {
                XCTAssertEqual(subscription.history,
                               [.requested(.max(1))],
                               "failure for subscription \(i)")
            }
            XCTAssertEqual(tracking.history, [.subscription("Merge")])

            // No downstream demand, these values are buffered
            for (i, publisher) in publishers.reversed().enumerated() {
                XCTAssertEqual(publisher.send(-i), .none) // ignored
                XCTAssertEqual(publisher.send(i), .none)
            }

            XCTAssertEqual(tracking.history, [.subscription("Merge")])

            // Establishing downstream demand
            downstreamSubscription?.request(.max(arity))
            downstreamSubscription?.request(.max(arity))

            for (i, subscription) in subscriptions.enumerated() {
                XCTAssertEqual(subscription.history,
                               [.requested(.max(1)),
                                .requested(.max(1))],
                               "failure for subscription \(i)")
            }
            let expectedValues: [TrackingSubscriber.Event] = (0 ..< arity)
                .reversed()
                .map {
                    .value($0)
                }
            XCTAssertEqual(tracking.history,
                           [.subscription("Merge")] + expectedValues)

            // Requesting more elements
            downstreamSubscription?.request(.max(arity))

            // Satisfying the unfullfilled demand
            for (i, publisher) in publishers.reversed().enumerated() {
                XCTAssertEqual(publisher.send(i), .max(1))
            }

            XCTAssertEqual(
                tracking.history,
                [.subscription("Merge")] + expectedValues + expectedValues.reversed()
            )

            tracking.cancel()
        }

        test(forArity: 2) { publishers in
            Publishers.Merge(publishers[0],
                             publishers[1])
        }

        test(forArity: 3) { publishers in
            Publishers.Merge3(publishers[0],
                              publishers[1],
                              publishers[2])
        }

        test(forArity: 4) { publishers in
            Publishers.Merge4(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3])
        }

        test(forArity: 4) { publishers in
            Publishers.Merge4(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3])
        }

        test(forArity: 5) { publishers in
            Publishers.Merge5(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3],
                              publishers[4])
        }

        test(forArity: 6) { publishers in
            Publishers.Merge6(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3],
                              publishers[4],
                              publishers[5])
        }

        test(forArity: 7) { publishers in
            Publishers.Merge7(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3],
                              publishers[4],
                              publishers[5],
                              publishers[6])
        }

        test(forArity: 8) { publishers in
            Publishers.Merge8(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3],
                              publishers[4],
                              publishers[5],
                              publishers[6],
                              publishers[7])
        }

        test(forArity: 0) { _ in
            Publishers.MergeMany<CustomPublisher>()
        }

        test(forArity: 2) { publishers in
            Publishers.MergeMany(publishers[0], publishers[1])
        }

        test(forArity: 20) { publishers in
            Publishers.MergeMany(publishers)
        }
    }

    func testMergeUnimitedInitialDemand() {
        func test<Merger: Publisher>(
            forArity arity: Int,
            _ makeMerger: ([CustomPublisher]) -> Merger
        ) where Merger.Output == Int, Merger.Failure == TestingError {
            let (subscriptions, publishers) = createTestPublishers(arity: arity)
            let merger = makeMerger(publishers)
            var downstreamSubscription: Subscription?
            let tracking = TrackingSubscriber(
                receiveSubscription: {
                    $0.request(.unlimited)
                    downstreamSubscription = $0
                },
                receiveValue: { _ in .max(3) }
            )
            merger.subscribe(tracking)

            for (i, subscription) in subscriptions.enumerated() {
                XCTAssertEqual(subscription.history,
                               [.requested(.max(1)),
                                .requested(.unlimited)],
                               "failure for subscription \(i)")
            }

            if arity == 0 {
                XCTAssertEqual(tracking.history, [.subscription("Merge"),
                                                  .completion(.finished)])
            } else {
                XCTAssertEqual(tracking.history, [.subscription("Merge")])
            }

            downstreamSubscription?.request(.max(42))
            downstreamSubscription?.request(.unlimited)

            for (i, subscription) in subscriptions.enumerated() {
                XCTAssertEqual(subscription.history,
                               [.requested(.max(1)),
                                .requested(.unlimited)],
                               "failure for subscription \(i)")
            }

            for (i, publisher) in publishers.reversed().enumerated() {
                XCTAssertEqual(publisher.send(i), .max(3))
            }

            let expectedValues: [TrackingSubscriber.Event] = (0 ..< arity).map {
                .value($0)
            }

            if arity == 0 {
                XCTAssertEqual(tracking.history, [.subscription("Merge"),
                                                  .completion(.finished)])
            } else {
                XCTAssertEqual(tracking.history,
                               [.subscription("Merge")] + expectedValues)
            }


            for (i, publisher) in publishers.enumerated() {
                XCTAssertEqual(publisher.send(i), .max(3))
            }

            if arity == 0 {
                XCTAssertEqual(tracking.history, [.subscription("Merge"),
                                                  .completion(.finished)])
            } else {
                XCTAssertEqual(tracking.history,
                               [.subscription("Merge")] + expectedValues + expectedValues)
            }

            tracking.cancel()
        }

        test(forArity: 2) { publishers in
            Publishers.Merge(publishers[0],
                             publishers[1])
        }

        test(forArity: 3) { publishers in
            Publishers.Merge3(publishers[0],
                              publishers[1],
                              publishers[2])
        }

        test(forArity: 4) { publishers in
            Publishers.Merge4(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3])
        }

        test(forArity: 4) { publishers in
            Publishers.Merge4(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3])
        }

        test(forArity: 5) { publishers in
            Publishers.Merge5(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3],
                              publishers[4])
        }

        test(forArity: 6) { publishers in
            Publishers.Merge6(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3],
                              publishers[4],
                              publishers[5])
        }

        test(forArity: 7) { publishers in
            Publishers.Merge7(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3],
                              publishers[4],
                              publishers[5],
                              publishers[6])
        }

        test(forArity: 8) { publishers in
            Publishers.Merge8(publishers[0],
                              publishers[1],
                              publishers[2],
                              publishers[3],
                              publishers[4],
                              publishers[5],
                              publishers[6],
                              publishers[7])
        }

        test(forArity: 0) { _ in
            Publishers.MergeMany<CustomPublisher>()
        }

        test(forArity: 2) { publishers in
            Publishers.MergeMany(publishers[0], publishers[1])
        }

        test(forArity: 20) { publishers in
            Publishers.MergeMany(publishers)
        }
    }

    func testMergeReflection() throws {
        func testMergeSubscriptionReflection<Sut: Publisher>(_ sut: Sut) throws {
            try testSubscriptionReflection(
                description: "Merge",
                customMirror: childrenIsEmpty,
                playgroundDescription: "Merge",
                sut: sut
            )
        }
        func testMergeSideReflection<Merger: Publisher>(
            _ makeMerger: (CustomPublisher) -> Merger
        ) throws where Merger.Output == Int, Merger.Failure == TestingError {
            try testReflection(parentInput: Int.self,
                               parentFailure: TestingError.self,
                               description: "Merge",
                               customMirror: expectedChildren(
                                   ("parentSubscription", .anything)
                               ),
                               playgroundDescription: "Merge",
                               makeMerger)
            let publisher = CustomPublisher(subscription: CustomSubscription())
            let merger = makeMerger(publisher)
            let tracking = TrackingSubscriber()
            merger.subscribe(tracking)
            let side = try XCTUnwrap(publisher.erasedSubscriber)
            let expectedParentID =
                try XCTUnwrap(tracking.subscriptions.first?.combineIdentifier)
            let actualParentID = Mirror(reflecting: side)
                .descendant("parentSubscription") as? CombineIdentifier
            XCTAssertEqual(expectedParentID, actualParentID)
        }

        let publisher = CustomPublisher(subscription: CustomSubscription())

        try testMergeSubscriptionReflection(
            publisher.merge(with: publisher) as Publishers.Merge
        )
        try testMergeSideReflection {
            $0.merge(with: publisher) as Publishers.Merge
        }

        try testMergeSubscriptionReflection(
            publisher.merge(with: publisher,
                            publisher) as Publishers.Merge3
        )
        try testMergeSideReflection {
            $0.merge(with: publisher,
                     publisher) as Publishers.Merge3
        }

        try testMergeSubscriptionReflection(
            publisher.merge(with: publisher,
                            publisher,
                            publisher) as Publishers.Merge4
        )
        try testMergeSideReflection {
            $0.merge(with: publisher,
                     publisher,
                     publisher) as Publishers.Merge4
        }

        try testMergeSubscriptionReflection(
            publisher.merge(with: publisher,
                            publisher,
                            publisher,
                            publisher) as Publishers.Merge5
        )
        try testMergeSideReflection {
            $0.merge(with: publisher,
                     publisher,
                     publisher,
                     publisher) as Publishers.Merge5
        }

        try testMergeSubscriptionReflection(
            publisher.merge(with: publisher,
                            publisher,
                            publisher,
                            publisher,
                            publisher) as Publishers.Merge6
        )
        try testMergeSideReflection {
            $0.merge(with: publisher,
                     publisher,
                     publisher,
                     publisher,
                     publisher) as Publishers.Merge6
        }

        try testMergeSubscriptionReflection(
            publisher.merge(with: publisher,
                            publisher,
                            publisher,
                            publisher,
                            publisher,
                            publisher) as Publishers.Merge7
        )
        try testMergeSideReflection {
            $0.merge(with: publisher,
                     publisher,
                     publisher,
                     publisher,
                     publisher,
                     publisher) as Publishers.Merge7
        }

        try testMergeSubscriptionReflection(
            publisher.merge(with: publisher,
                            publisher,
                            publisher,
                            publisher,
                            publisher,
                            publisher,
                            publisher) as Publishers.Merge8
        )
        try testMergeSideReflection {
            $0.merge(with: publisher,
                     publisher,
                     publisher,
                     publisher,
                     publisher,
                     publisher,
                     publisher) as Publishers.Merge8
        }

        try testMergeSubscriptionReflection(
            publisher.merge(with: publisher) as Publishers.MergeMany
        )
        try testMergeSideReflection {
            $0.merge(with: $0) as Publishers.MergeMany
        }
    }
}
