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

    func testCatchRecursion() {
        testRecursion(expectedSubscription: "Catch") {
            $0.catch($1)
        }
    }

    func testCatchReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 1, expected: .crash) {
            $0.catch { _ in Just(13) }
        }
    }

    func testCatchReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.catch { _ in Just(13) } }
        )
    }

    func testCatchRequestPendingPost() {
        CatchTests.testRequestPendingPost(expectedSubscription: "Catch",
                                          { $0.catch($1) })
    }

    func testCatchCancelPendingPost() {
        CatchTests.testCancelPendingPost(expectedSubscription: "Catch",
                                         { $0.catch($1) })
    }

    func testCatchRequestPost() throws {
        try CatchTests.testRequestPost(expectedSubscription: "Catch",
                                       { $0.catch($1) })
    }

    func testCatchCancellationBeforeRecovering() throws {
        try CatchTests.testCancellationBeforeRecovering(expectedSubscription: "Catch",
                                                        { $0.catch($1) })
    }

    func testCatchCancellationAfterRecovering() throws {
        try CatchTests.testCancellationAfterRecovering(expectedSubscription: "Catch",
                                                       { $0.catch($1) })
    }

    func testCatchUpstreamFailsTwice() {
        testUpstreamFailsTwice(expectedSubscription: "Catch") { $0.catch($1) }
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

    func testTryCatchHandlerThrows() {

        var handledErrors = [TestingError]()

        func handler(_ error: TestingError) throws -> Just<Int> {
            handledErrors.append(error)
            throw "oops2" as TestingError
        }

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.tryCatch(handler) })

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryCatch"),
                        .value(1),
                        .value(2),
                        .completion(.failure("oops2" as TestingError))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(handledErrors, [.oops])

        XCTAssertEqual(helper.publisher.send(-1), .none)
        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryCatch"),
                        .value(1),
                        .value(2),
                        .completion(.failure("oops2" as TestingError)),
                        .value(-1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(handledErrors, [.oops])
    }

    func testTryCatchRecursion() {
        testRecursion(expectedSubscription: "TryCatch") {
            $0.tryCatch($1)
        }
    }

    func testTryCatchReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 1, expected: .crash) {
            $0.tryCatch { _ in Just(13) }
        }
    }

    func testTryCatchReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryCatch { _ in Just(13) } }
        )
    }

    func testTryCatchRequestPendingPost() {
        CatchTests.testRequestPendingPost(expectedSubscription: "TryCatch",
                                          { $0.tryCatch($1) })
    }

    func testTryCatchCancelPendingPost() {
        CatchTests.testCancelPendingPost(expectedSubscription: "TryCatch",
                                         { $0.tryCatch($1) })
    }

    func testTryCatchRequestPost() throws {
        try CatchTests.testRequestPost(expectedSubscription: "TryCatch",
                                       { $0.tryCatch($1) })
    }

    func testTryCatchCancellationBeforeRecovering() throws {
        try CatchTests.testCancellationBeforeRecovering(expectedSubscription: "TryCatch",
                                                        { $0.tryCatch($1) })
    }

    func testTryCatchCancellationAfterRecovering() throws {
        try CatchTests.testCancellationAfterRecovering(expectedSubscription: "TryCatch",
                                                       { $0.tryCatch($1) })
    }

    func testTryCatchUpstreamFailsTwice() {
        testUpstreamFailsTwice(expectedSubscription: "TryCatch") { $0.tryCatch($1) }
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

    private func testRecursion<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: @escaping (CustomPublisher,
                                @escaping (TestingError) -> Just<Int>) -> Operator
    ) where Operator.Output == Int {

        func createSut(_ publisher: CustomPublisher) -> Operator {
            return makeCatch(publisher) { _ in
                publisher.send(completion: .failure(.oops))
                return Just(13)
            }
        }

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: createSut
        )

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)

        assertCrashes {
            helper.publisher.send(completion: .failure(.oops))
        }
    }

    private static func testRequestPendingPost<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: (CustomPublisher,
                      @escaping (TestingError) -> CustomPublisher) -> Operator
    ) where Operator.Output == Int {

        let handlerSubscription = CustomSubscription()
        let handlerPublisher = CustomPublisher(subscription: handlerSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(3),
            receiveValueDemand: .none,
            createSut: { makeCatch($0) { _ in handlerPublisher } }
        )

        handlerPublisher.willSubscribe = { _, _ in
            guard let downstreamSubscription = helper.downstreamSubscription else {
                XCTFail("missing downstream subscription")
                return
            }
            downstreamSubscription.request(.max(10))
            XCTAssertEqual(handlerSubscription.history, [])
        }

        XCTAssertEqual(helper.publisher.send(1), .none)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(handlerSubscription.history, [.requested(.max(12))])
    }

    private static func testCancelPendingPost<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: (CustomPublisher,
                      @escaping (TestingError) -> CustomPublisher) -> Operator
    ) where Operator.Output == Int {

        let handlerSubscription = CustomSubscription()
        let handlerPublisher = CustomPublisher(subscription: handlerSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(3),
            receiveValueDemand: .none,
            createSut: { makeCatch($0) { _ in handlerPublisher } }
        )

        handlerPublisher.willSubscribe = { _, _ in
            guard let downstreamSubscription = helper.downstreamSubscription else {
                XCTFail("missing downstream subscription")
                return
            }
            downstreamSubscription.cancel()
            XCTAssertEqual(handlerSubscription.history, [])
        }

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(handlerSubscription.history, [.requested(.max(3))])

        handlerPublisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.finished)])
        XCTAssertEqual(handlerSubscription.history, [.requested(.max(3))])
    }

    private static func testRequestPost<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: (CustomPublisher,
                      @escaping (TestingError) -> CustomPublisher) -> Operator
    ) throws where Operator.Output == Int {

        let handlerSubscription = CustomSubscription()
        let handlerPublisher = CustomPublisher(subscription: handlerSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { makeCatch($0) { _ in handlerPublisher } }
        )

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertNotNil(handlerPublisher.subscriber)

        try XCTUnwrap(helper.downstreamSubscription).request(.max(12))
        XCTAssertEqual(handlerSubscription.history, [.requested(.max(12))])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])

        XCTAssertEqual(handlerPublisher.send(100), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(100)])
    }

    private static func testCancellationBeforeRecovering<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: (CustomPublisher,
                      @escaping (TestingError) -> CustomPublisher) -> Operator
    ) throws where Operator.Output == Int {

        func handler(_ error: TestingError) -> CustomPublisher {
            XCTFail("Should not be called")
            return CustomPublisher(subscription: CustomSubscription())
        }

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(3),
            createSut: { makeCatch($0, handler) }
        )

        let downstreamSubscription = try XCTUnwrap(helper.downstreamSubscription)

        downstreamSubscription.cancel()
        downstreamSubscription.request(.max(199))

        XCTAssertEqual(helper.publisher.send(1), .max(3))
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(1)])
    }

    private static func testCancellationAfterRecovering<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: (CustomPublisher,
                      @escaping (TestingError) -> CustomPublisher) -> Operator
    ) throws where Operator.Output == Int {

        let handlerSubscription = CustomSubscription()
        let handlerPublisher = CustomPublisher(subscription: handlerSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(3),
            createSut: { makeCatch($0) { _ in handlerPublisher } }
        )

        helper.publisher.send(completion: .failure(.oops))

        let downstreamSubscription = try XCTUnwrap(helper.downstreamSubscription)
        downstreamSubscription.cancel()

        XCTAssertEqual(handlerPublisher.send(1), .max(3))
        handlerPublisher.send(completion: .finished)
        handlerPublisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(1)])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(handlerSubscription.history, [.cancelled])

        let extraSubscription = CustomSubscription()
        handlerPublisher.send(subscription: extraSubscription)
        XCTAssertEqual(extraSubscription.history, [.cancelled])
    }

    private func testUpstreamFailsTwice<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeCatch: (CustomPublisher,
                      @escaping (TestingError) -> CustomPublisher) -> Operator
    ) where Operator.Output == Int {

        let handlerSubscription = CustomSubscription()
        let handlerPublisher = CustomPublisher(subscription: handlerSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .max(3),
            createSut: { makeCatch($0) { _ in handlerPublisher } }
        )

        helper.publisher.send(completion: .failure(.oops))

        assertCrashes {
            helper.publisher.send(completion: .failure(.oops))
        }
    }
}
