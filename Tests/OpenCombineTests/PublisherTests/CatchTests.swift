//
//  CatchTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CatchTests: XCTestCase {

    // MARK: - Catch

    func testSimpleCatch() {
        CatchTests
            .testWithSequence(expectedSubscription: "Catch") { upstream, new in
                upstream.catch { _ in new }
            }
    }

    func testCatchReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.catch(Fail.init) }
        try testReceiveSubscriptionTwice { publisher in
            Fail(outputType: Int.self, failure: TestingError.oops)
                .catch { _ in publisher }
        }
    }

    func testCatchCrashesOnUnwantedInput() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.catch { _ in Just(-1) } })
        assertCrashes {
            _ = helper.publisher.send(42)
        }
    }

    func testCatchPreservesDemand() throws {
        try CatchTests.testPreservesDemand(expectedSubscription: "Catch") {
            $0.catch($1)
        }
    }

    func testCatchUpstreamFinishes() {
        CatchTests.testUpstreamFinishes(expectedSubscription: "Catch") {
            $0.catch($1)
        }
    }

    func testCatchReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "Catch",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("demand", "max(0)")
                           ),
                           playgroundDescription: "Catch",
                           { $0.catch(Fail.init) })

        try testReflection(
            parentInput: Int.self,
            parentFailure: TestingError.self,
            description: "Catch",
            customMirror: expectedChildren(
                ("downstream", .contains("TrackingSubscriberBase")),
                ("demand", "max(0)")
            ),
            playgroundDescription: "Catch",
            { publisher in
                Fail(outputType: Int.self, failure: TestingError.oops)
                    .catch { _ in publisher }
            }
        )
    }

    // MARK: - TryCatch

    func testSimpleTryCatch() {
        CatchTests
            .testWithSequence(expectedSubscription: "TryCatch") { upstream, new in
                upstream.tryCatch { _ in new }
            }
    }

    func testTryCatchReceiveSubscriptionTwice() throws {

        try testReceiveSubscriptionTwice { $0.tryCatch(Fail.init) }

        try testReceiveSubscriptionTwice { publisher in
            Fail(outputType: Int.self, failure: TestingError.oops)
                .tryCatch { _ in publisher }
        }
    }

    func testTryCatchCrashesOnUnwantedInput() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.tryCatch { _ in Just(-1) } })
        assertCrashes {
            _ = helper.publisher.send(42)
        }
    }

    func testTryCatchPreservesDemand() throws {
        try CatchTests.testPreservesDemand(expectedSubscription: "TryCatch") {
            $0.tryCatch($1)
        }
    }

    func testTryCatchUpstreamFinishes() {
        CatchTests.testUpstreamFinishes(expectedSubscription: "TryCatch") {
            $0.tryCatch($1)
        }
    }

    func testTryCatchReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "TryCatch",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("demand", "max(0)")
                           ),
                           playgroundDescription: "TryCatch",
                           { $0.tryCatch(Fail.init) })

        try testReflection(
            parentInput: Int.self,
            parentFailure: TestingError.self,
            description: "TryCatch",
            customMirror: expectedChildren(
                ("downstream", .contains("TrackingSubscriberBase")),
                ("demand", "max(0)")
            ),
            playgroundDescription: "TryCatch",
            { publisher in
                Fail<Int, TestingError>(error: .oops).tryCatch { _ in publisher }
            }
        )
    }

    // MARK: - Generic tests

    private typealias TestSequence = Publishers.Sequence<[Int], Never>

    private static func testWithSequence<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: (Publishers.TryMap<TestSequence, Int>, TestSequence) -> Operator
    ) where Operator.Output == Int {
        let throwingSequence = TestSequence(sequence: Array(0 ..< 10))
            .tryMap { v -> Int in
                if v < 5 {
                    return v
                } else {
                    throw TestingError.oops
                }
            }

        let `catch` = makeCatch(throwingSequence, [3, 2, 1, 0].publisher)

        let tracking = TrackingSubscriberBase<Int, Operator.Failure>(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: { _ in .max(1) }
        )
        `catch`.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(expectedSubscription),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .value(3),
                                          .value(2),
                                          .value(1),
                                          .value(0),
                                          .completion(.finished)])
    }

    private static func testPreservesDemand<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch:
            (CustomPublisher,
             @escaping (TestingError) -> CustomPublisherBase<Int, Error>) -> Operator
    ) throws where Operator.Output == Int {

        let errorHandlerSubscription = CustomSubscription()
        let errorHandlerPublisher = CustomPublisherBase<Int, Error>(
            subscription: errorHandlerSubscription
        )

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(12),
            receiveValueDemand: .max(3),
            createSut: { makeCatch($0) { _ in errorHandlerPublisher } }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(12))])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))

        XCTAssertEqual(helper.subscription.history, [.requested(.max(12)),
                                                     .requested(.max(5))])

        for i in 1 ... 8 {
            XCTAssertEqual(helper.publisher.send(i), .max(3))
        }

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4),
                                                 .value(5),
                                                 .value(6),
                                                 .value(7),
                                                 .value(8)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(12)),
                                                     .requested(.max(5))])
        XCTAssertEqual(errorHandlerSubscription.history, [.requested(.max(33))])
    }

    private static func testUpstreamFinishes<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: (CustomPublisher,
                      @escaping (TestingError) -> Fail<Int, Error>) -> Operator
    ) where Operator.Output == Int {
        var counter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .none,
            createSut: { makeCatch($0) { counter += 1; return Fail(error: $0) } }
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(1),
                                                 .value(2),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
        XCTAssertEqual(counter, 0)
    }
}
