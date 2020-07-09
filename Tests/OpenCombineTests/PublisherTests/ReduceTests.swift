//
//  ReduceTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ReduceTests: XCTestCase {

    // MARK: - Reduce

    func testReduceBasicBehavior() throws {
        try ReduceTests.testBasicReductionBehavior(expectedSubscription: "Reduce",
                                                   expectedResult: 120,
                                                   { $0.reduce(1, *) })
    }

    func testReduceFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Reduce") {
            $0.reduce(1, *)
        }
    }

    func testReduceFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "Reduce",
                                                    expectedResult: 1) {
            $0.reduce(1, *)
        }
    }

    func testReduceRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.reduce(0, +) }
    }

    func testReduceReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "Reduce",
            expectedResult: .normalCompletion(0),
            { $0.reduce(0, +) }
        )
    }

    func testReduceReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.reduce(0, shouldNotBeCalled()) })
    }

    func testReduceReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.reduce(0, shouldNotBeCalled()) }
        )
    }

    func testReduceRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.reduce(0, shouldNotBeCalled()) })
    }

    func testReduceCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.reduce(0, shouldNotBeCalled()) })
    }

    func testReduceLifecycle() throws {
        try testLifecycle(sendValue: 42,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.reduce(0, +) })
    }

    func testReduceReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Reduce",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "Reduce",
                           { $0.reduce(0, +) })
    }

    // MARK: - TryReduce

    func testTryReduceBasicBehavior() throws {
        try ReduceTests.testBasicReductionBehavior(expectedSubscription: "TryReduce",
                                                   expectedResult: 120,
                                                   { $0.tryReduce(1, *) })
    }

    func testTryReduceFailureBecauseOfThrow() throws {

        func reducer(_ accumulator: Int, _ newValue: Int) throws -> Int {
            if newValue == 5 {
                throw TestingError.oops
            }
            return accumulator * newValue
        }

        try ReduceTests.testFailureBecauseOfThrow(expectedSubscription: "TryReduce",
                                                  expectedFailure: TestingError.oops,
                                                  { $0.tryReduce(1, reducer) })
    }

    func testTryReduceFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "TryReduce") {
            $0.tryReduce(1, *)
        }
    }

    func testTryReduceFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "TryReduce",
                                                    expectedResult: 1) {
            $0.tryReduce(1, *)
        }
    }

    func testTryReduceRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.tryReduce(0, +) }
    }

    func testTryReduceReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryReduce",
            expectedResult: .normalCompletion(0),
            { $0.tryReduce(0, +) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryReduce",
            expectedResult: .failure(TestingError.oops),
            { $0.tryReduce(0, { _, _ in throw TestingError.oops }) }
        )
    }

    func testTryReduceReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.tryReduce(0, shouldNotBeCalled()) })
    }

    func testTryReduceReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryReduce(0, shouldNotBeCalled()) }
        )
    }

    func testTryReduceRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryReduce(0, shouldNotBeCalled()) })
    }

    func testTryReduceCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.tryReduce(0, shouldNotBeCalled()) })
    }

    func testTryReduceLifecycle() throws {
        try testLifecycle(sendValue: 42,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryReduce(0, +) })
    }

    func testTryReduceReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryReduce",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "TryReduce",
                           { $0.tryReduce(0, +) })
    }

    // MARK: - Generic tests

    enum PartialCompletion<Value, Failure: Error> {
        case normalCompletion(Value?)
        case earlyCompletion(Value)
        case failure(Failure)
    }

    /// The test publishes integers from 1 to 5, then finishes.
    ///
    /// This is expected to complete normally, i. e., not earlier than receiving
    /// the last value from the upstream.
    static func testBasicReductionBehavior<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        expectedResult: Operator.Output,
        _ makeOperator: (CustomPublisherBase<Int, Never>) -> Operator
    ) throws where Operator.Output: Equatable {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Never>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: makeOperator
        )

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(5), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(expectedResult),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    /// The test publishes integers from 1 to 5 and expects the stream to fail.
    static func testFailureBecauseOfThrow<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        expectedFailure: Operator.Failure,
        _ makeOperator: (CustomPublisherBase<Int, Never>) -> Operator
    ) throws where Operator.Output: Equatable {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Never>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: makeOperator
        )

        helper.tracking.onFailure = { _ in
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
        }

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(5), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.failure(expectedFailure))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.failure(expectedFailure))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    static func testUpstreamFinishesWithError<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    ) where Operator.Output: Equatable, Operator.Failure == Error {

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Error>.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(1),
            createSut: makeOperator
        )

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history,
                       [.subscription(expectedSubscription),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history,
                       [.subscription(expectedSubscription),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(73), .none)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history,
                       [.subscription(expectedSubscription),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    static func testUpstreamFinishesImmediately<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        expectedResult: Operator.Output?,
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    ) where Operator.Output: Equatable, Operator.Failure == Error {

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Error>.self,
            initialDemand: nil, // Downstream should receive the result nonetheless
            receiveValueDemand: .none,
            createSut: makeOperator
        )

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .finished)

        let expectedHistory: [TrackingSubscriberBase<Operator.Output, Error>.Event]
        if let expectedResult = expectedResult {
            expectedHistory = [.subscription(expectedSubscription),
                               .value(expectedResult),
                               .completion(.finished)]
        } else {
           expectedHistory = [.subscription(expectedSubscription), .completion(.finished)]
        }
        XCTAssertEqual(helper.tracking.history, expectedHistory)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history, expectedHistory)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(73), .none)
        XCTAssertEqual(helper.tracking.history, expectedHistory)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    static func testCancelAlreadyCancelled<Operator: Publisher>(
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    ) throws where Operator.Output: Equatable, Operator.Failure == Error {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Error>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: makeOperator
        )

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
    }

    static func testRequestsUnlimitedThenSendsSubscription<Operator: Publisher>(
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    ) where Operator.Output: Equatable, Operator.Failure == Error {
        var didReceiveSubscription = false
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Error>(subscription: subscription)
        let operatorPublisher = makeOperator(publisher)
        let tracking = TrackingSubscriberBase<Operator.Output, Error>(
            receiveSubscription: { _ in
                XCTAssertEqual(subscription.history, [])
                didReceiveSubscription = true
            }
        )
        XCTAssertFalse(didReceiveSubscription)
        XCTAssertEqual(subscription.history, [])

        operatorPublisher.subscribe(tracking)

        XCTAssertTrue(didReceiveSubscription)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    /// The test publishes `0`, and then finishes.
    static func testReceiveSubscriptionTwice<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        expectedResult: PartialCompletion<Operator.Output, Operator.Failure>,
        _ makeOperator: (CustomPublisher) -> Operator
    ) throws where Operator.Output: Equatable {

        typealias Subscriber = TrackingSubscriberBase<Operator.Output, Operator.Failure>

        let firstSubscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: firstSubscription)
        let operatorPublisher = makeOperator(publisher)
        let tracking = Subscriber(receiveSubscription: { $0.request(.max(1)) })
        operatorPublisher.subscribe(tracking)

        XCTAssertEqual(firstSubscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription(expectedSubscription)])

        let secondSubscription = CustomSubscription()
        try XCTUnwrap(publisher.subscriber).receive(subscription: secondSubscription)

        XCTAssertEqual(firstSubscription.history, [.requested(.unlimited)])
        XCTAssertEqual(secondSubscription.history, [.cancelled])
        XCTAssertEqual(tracking.history, [.subscription(expectedSubscription)])

        XCTAssertEqual(publisher.send(0), .none)
        publisher.send(completion: .finished)

        let expectedSubscriberHistory: [Subscriber.Event]
        let expectedSubscriptionHistory: [CustomSubscription.Event]
        switch expectedResult {
        case .normalCompletion(nil):
            expectedSubscriberHistory = [.subscription(expectedSubscription),
                                         .completion(.finished)]
            expectedSubscriptionHistory = [.requested(.unlimited)]
        case let .normalCompletion(value?):
            expectedSubscriberHistory = [.subscription(expectedSubscription),
                                         .value(value),
                                         .completion(.finished)]
            expectedSubscriptionHistory = [.requested(.unlimited)]
        case let .earlyCompletion(value):
            expectedSubscriberHistory = [.subscription(expectedSubscription),
                                         .value(value),
                                         .completion(.finished)]
            expectedSubscriptionHistory = [.requested(.unlimited), .cancelled]
        case let .failure(error):
            expectedSubscriberHistory = [.subscription(expectedSubscription),
                                         .completion(.failure(error))]
            expectedSubscriptionHistory = [.requested(.unlimited), .cancelled]
        }

        XCTAssertEqual(firstSubscription.history, expectedSubscriptionHistory)
        XCTAssertEqual(secondSubscription.history, [.cancelled])

        XCTAssertEqual(tracking.history, expectedSubscriberHistory)
        try XCTUnwrap(publisher.subscriber).receive(subscription: secondSubscription)

        XCTAssertEqual(firstSubscription.history, expectedSubscriptionHistory)
        XCTAssertEqual(secondSubscription.history, [.cancelled, .cancelled])
        XCTAssertEqual(tracking.history, expectedSubscriberHistory)
    }
}
