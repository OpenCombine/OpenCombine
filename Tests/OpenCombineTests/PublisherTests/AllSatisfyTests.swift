//
//  AllSatisfyTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 15.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class AllSatisfyTests: XCTestCase {

    // MARK: - AllSatisfy

    func testAllSatisfyAllElementsSatisfyPredicate() {
        AllSatisfyTests.testAllElementsSatisfyPredicate(
            expectedSubscription: "AllSatisfy",
            expectedResult: true,
            { upstream, predicate in upstream.allSatisfy(predicate) }
        )
    }

    func testAllSatisfyContainsElementNotSatisfyingPredicate() {
        AllSatisfyTests.testContainsElementNotSatisfyingPredicate(
            expectedSubscription: "AllSatisfy",
            expectedResult: false,
            { upstream, predicate in upstream.allSatisfy(predicate) }
        )
    }

    func testAllSatisfyUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(
            expectedSubscription: "AllSatisfy",
            { $0.allSatisfy(shouldNotBeCalled()) }
        )
    }

    func testAllSatisfyUpstreamFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(
            expectedSubscription: "AllSatisfy",
            expectedResult: true,
            { $0.allSatisfy(shouldNotBeCalled()) }
        )
    }

    func testAllSatisfyCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled {
            $0.allSatisfy(shouldNotBeCalled())
        }
    }

    func testAllSatisfyRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.allSatisfy(shouldNotBeCalled())
        }
    }

    func testAllSatisfyReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "AllSatisfy",
            expectedResult: .earlyCompletion(false),
            { $0.allSatisfy { $0 > 0 } }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "AllSatisfy",
            expectedResult: .normalCompletion(true),
            { $0.allSatisfy { $0 == 0 } }
        )
    }

    func testAllSatisfyReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.allSatisfy(shouldNotBeCalled()) })
    }

    func testAllSatisfyReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.allSatisfy(shouldNotBeCalled()) }
        )
    }

    func testAllSatisfyRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.allSatisfy(shouldNotBeCalled()) })
    }

    func testAllSatisfyCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.allSatisfy(shouldNotBeCalled()) })
    }

    func testAllSatisfyLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.allSatisfy { _ in true } })
    }

    func testAllSatisfyReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "AllSatisfy",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "AllSatisfy",
                           { $0.allSatisfy(shouldNotBeCalled()) })
    }

    // MARK: - TryAllSatisfy

    func testTryAllSatisfyAllElementsSatisfyPredicate() {
        AllSatisfyTests.testAllElementsSatisfyPredicate(
            expectedSubscription: "TryAllSatisfy",
            expectedResult: true,
            { upstream, predicate in upstream.tryAllSatisfy(predicate) }
        )
    }

    func testTryAllSatisfyContainsElementNotSatisfyingPredicate() {
        AllSatisfyTests.testContainsElementNotSatisfyingPredicate(
            expectedSubscription: "TryAllSatisfy",
            expectedResult: false,
            { upstream, predicate in upstream.tryAllSatisfy(predicate) }
        )
    }

    func testFailureBecauseOfThrow() throws {

        func predicate(_ input: Int) throws -> Bool {
            if input == 3 {
                throw TestingError.oops
            }
            return input < 3
        }

        try ReduceTests.testFailureBecauseOfThrow(expectedSubscription: "TryAllSatisfy",
                                                  expectedFailure: TestingError.oops,
                                                  { $0.tryAllSatisfy(predicate) })
    }

    func testTryAllSatisfyUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(
            expectedSubscription: "TryAllSatisfy",
            { $0.tryAllSatisfy(shouldNotBeCalled()) }
        )
    }

    func testTryAllSatisfyUpstreamFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(
            expectedSubscription: "TryAllSatisfy",
            expectedResult: true,
            { $0.tryAllSatisfy(shouldNotBeCalled()) }
        )
    }

    func testTryAllSatisfyCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled {
            $0.tryAllSatisfy(shouldNotBeCalled())
        }
    }

    func testTryAllSatisfyRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.tryAllSatisfy(shouldNotBeCalled())
        }
    }

    func testTryAllSatisfyReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryAllSatisfy",
            expectedResult: .earlyCompletion(false),
            { $0.tryAllSatisfy { $0 > 0 } }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryAllSatisfy",
            expectedResult: .normalCompletion(true),
            { $0.tryAllSatisfy { $0 == 0 } }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryAllSatisfy",
            expectedResult: .failure(TestingError.oops),
            { $0.tryAllSatisfy { _ in throw TestingError.oops } }
        )
    }

    func testTryAllSatisfyReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.tryAllSatisfy(shouldNotBeCalled()) })
    }

    func testTryAllSatisfyReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryAllSatisfy(shouldNotBeCalled()) }
        )
    }

    func testTryAllSatisfyRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryAllSatisfy(shouldNotBeCalled()) })
    }

    func testTryAllSatisfyCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.tryAllSatisfy(shouldNotBeCalled()) })
    }

    func testTryAllSatisfyLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryAllSatisfy { _ in true } })
    }

    func testTryAllSatisfyReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryAllSatisfy",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "TryAllSatisfy",
                           { $0.tryAllSatisfy(shouldNotBeCalled()) })
    }

    // MARK: - Generic tests

    /// Publishes -2, 0, 2, 4, 7
    static func testAllElementsSatisfyPredicate<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        expectedResult: Bool,
        countPredicateCalls: Bool = true,
        _ makeOperator: (CustomPublisher, @escaping (Int) -> Bool) -> Operator
    ) where Operator.Output == Bool {

        var predicateCounter = 0

        func predicate(_ value: Int) -> Bool {
            predicateCounter += 1
            return value.isMultiple(of: 2)
        }

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: { makeOperator($0, predicate) }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])

        XCTAssertEqual(helper.publisher.send(-2), .none)
        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)

        if countPredicateCalls {
            XCTAssertEqual(predicateCounter, 4)
        }

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(expectedResult),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(7), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(expectedResult),
                                                 .completion(.finished)])

        if countPredicateCalls {
            XCTAssertEqual(predicateCounter, 4)
        }
    }

    /// Publishes -2, 0, 2, 4, 7, 8, 3
    static func testContainsElementNotSatisfyingPredicate<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        expectedResult: Bool,
        countPredicateCalls: Bool = true,
        _ makeOperator: (CustomPublisher, @escaping (Int) -> Bool) -> Operator
    ) where Operator.Output == Bool {

        var predicateCounter = 0

        func predicate(_ value: Int) -> Bool {
            predicateCounter += 1
            return value.isMultiple(of: 2)
        }

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: { makeOperator($0, predicate) }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])

        XCTAssertEqual(helper.publisher.send(-2), .none)
        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)

        if countPredicateCalls {
            XCTAssertEqual(predicateCounter, 4)
        }

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])

        XCTAssertEqual(helper.publisher.send(7), .none)

        if countPredicateCalls {
            XCTAssertEqual(predicateCounter, 5)
        }

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(expectedResult),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(8), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(expectedResult),
                                                 .completion(.finished)])

        if countPredicateCalls {
            XCTAssertEqual(predicateCounter, 5)
        }
    }
}
