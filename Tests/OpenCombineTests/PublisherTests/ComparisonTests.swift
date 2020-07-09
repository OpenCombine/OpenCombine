//
//  ComparisonTests.swift
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
final class ComparisonTests: XCTestCase {

    // MARK: - Comparison

    func testComparisonBasicBehavior() {
        ComparisonTests.testBasicBehavior(
            expectedSubscription: "Comparison",
            expectedResult: 15,
            semantics: .max,
            countComparatorCalls: false,
            { upstream, _ in upstream.max() }
        )

        ComparisonTests.testBasicBehavior(
            expectedSubscription: "Comparison",
            expectedResult: 1,
            semantics: .min,
            countComparatorCalls: false,
            { upstream, _ in upstream.min() }
        )

        ComparisonTests.testBasicBehavior(
            expectedSubscription: "Comparison",
            expectedResult: 8,
            semantics: .max,
            { upstream, comparator in upstream.max(by: comparator) }
        )

        ComparisonTests.testBasicBehavior(
            expectedSubscription: "Comparison",
            expectedResult: 1,
            semantics: .min,
            { upstream, comparator in upstream.min(by: comparator) }
        )
    }

    func testComparisonUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Comparison",
                                                  { $0.max() })

        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Comparison",
                                                  { $0.min() })

        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Comparison",
                                                  { $0.max(by: shouldNotBeCalled()) })

        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Comparison",
                                                  { $0.min(by: shouldNotBeCalled()) })
    }

    func testComparisonUpstreamFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "Comparison",
                                                    expectedResult: nil,
                                                    { $0.max() })

        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "Comparison",
                                                    expectedResult: nil,
                                                    { $0.min() })

        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "Comparison",
                                                    expectedResult: nil,
                                                    { $0.max(by: shouldNotBeCalled()) })

        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "Comparison",
                                                    expectedResult: nil,
                                                    { $0.min(by: shouldNotBeCalled()) })
    }

    func testComparisonCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.max() }
        try ReduceTests.testCancelAlreadyCancelled { $0.min() }
        try ReduceTests.testCancelAlreadyCancelled { $0.max(by: shouldNotBeCalled()) }
        try ReduceTests.testCancelAlreadyCancelled { $0.min(by: shouldNotBeCalled()) }
    }

    func testComparisonRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.max() }

        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.min() }

        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.max(by: shouldNotBeCalled())
        }

        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.min(by: shouldNotBeCalled())
        }
    }

    func testComparisonReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(expectedSubscription: "Comparison",
                                                     expectedResult: .normalCompletion(0),
                                                     { $0.max() })

        try ReduceTests.testReceiveSubscriptionTwice(expectedSubscription: "Comparison",
                                                     expectedResult: .normalCompletion(0),
                                                     { $0.min() })

        try ReduceTests.testReceiveSubscriptionTwice(expectedSubscription: "Comparison",
                                                     expectedResult: .normalCompletion(0),
                                                     { $0.max(by: shouldNotBeCalled()) })

        try ReduceTests.testReceiveSubscriptionTwice(expectedSubscription: "Comparison",
                                                     expectedResult: .normalCompletion(0),
                                                     { $0.min(by: shouldNotBeCalled()) })
    }

    func testComparisonReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.min() })

        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.max() })

        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.min(by: shouldNotBeCalled()) })

        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.max(by: shouldNotBeCalled()) })
    }

    func testComparisonReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.min() }
        )

        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.max() }
        )

        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.min(by: shouldNotBeCalled()) }
        )

        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.max(by: shouldNotBeCalled()) }
        )
    }

    func testComparisonRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.min() })

        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.max() })

        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.min(by: shouldNotBeCalled()) })

        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.max(by: shouldNotBeCalled()) })
    }

    func testComparisonCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.min() })

        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.max() })

        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.min(by: shouldNotBeCalled()) })

        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.max(by: shouldNotBeCalled()) })
    }

    func testComparisonLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.min(by: >) })

        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.max(by: >) })
    }

    func testComparisonReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Comparison",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "Comparison",
                           { $0.min(by: shouldNotBeCalled()) })

        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Comparison",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "Comparison",
                           { $0.max(by: shouldNotBeCalled()) })
    }

    // MARK: - TryComparison

    func testTryComparisonBasicBehavior() {

        ComparisonTests.testBasicBehavior(
            expectedSubscription: "TryComparison",
            expectedResult: 8,
            semantics: .max,
            { upstream, comparator in upstream.tryMax(by: comparator) }
        )

        ComparisonTests.testBasicBehavior(
            expectedSubscription: "TryComparison",
            expectedResult: 1,
            semantics: .min,
            { upstream, comparator in upstream.tryMin(by: comparator) }
        )
    }

    func testTryComparisonFailureBecauseOfThrow() throws {

        func comparator(_ lhs: Int, _ rhs: Int) throws -> Bool {
            if lhs == 3 {
                throw TestingError.oops
            }
            return lhs < rhs
        }

        try ReduceTests.testFailureBecauseOfThrow(expectedSubscription: "TryComparison",
                                                  expectedFailure: TestingError.oops,
                                                  { $0.tryMax(by: comparator) })

        try ReduceTests.testFailureBecauseOfThrow(expectedSubscription: "TryComparison",
                                                  expectedFailure: TestingError.oops,
                                                  { $0.tryMin(by: comparator) })
    }

    func testTryComparisonUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "TryComparison",
                                                  { $0.tryMax(by: >) })

        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "TryComparison",
                                                  { $0.tryMin(by: >) })
    }

    func testTryComparisonUpstreamFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "TryComparison",
                                                    expectedResult: nil,
                                                    { $0.tryMax(by: >) })

        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "TryComparison",
                                                    expectedResult: nil,
                                                    { $0.tryMin(by: >) })
    }

    func testTryComparisonCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.tryMax(by: shouldNotBeCalled()) }
        try ReduceTests.testCancelAlreadyCancelled { $0.tryMin(by: shouldNotBeCalled()) }
    }

    func testTryComparisonRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.tryMax(by: shouldNotBeCalled())
        }

        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.tryMin(by: shouldNotBeCalled())
        }
    }

    func testTryComparisonReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryComparison",
            expectedResult: .normalCompletion(0),
            { $0.tryMax(by: shouldNotBeCalled()) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryComparison",
            expectedResult: .normalCompletion(0),
            { $0.tryMin(by: shouldNotBeCalled()) }
        )
    }

    func testTryComparisonReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.tryMin(by: shouldNotBeCalled()) })

        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.tryMax(by: shouldNotBeCalled()) })
    }

    func testTryComparisonReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryMin(by: shouldNotBeCalled()) }
        )

        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryMax(by: shouldNotBeCalled()) }
        )
    }

    func testTryComparisonRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryMin(by: shouldNotBeCalled()) })

        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryMax(by: shouldNotBeCalled()) })
    }

    func testTryComparisonCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.tryMin(by: shouldNotBeCalled()) })

        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.tryMax(by: shouldNotBeCalled()) })
    }

    func testTryComparisonLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryMin(by: >) })

        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryMax(by: >) })
    }

    func testTryComparisonReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryComparison",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "TryComparison",
                           { $0.tryMin(by: shouldNotBeCalled()) })

        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryComparison",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "TryComparison",
                           { $0.tryMax(by: shouldNotBeCalled()) })
    }

    // MARK: - Generic tests

    private enum ComparisonSemantics {
        case min
        case max
    }

    private struct ComparisonHistoryElement: Equatable, CustomStringConvertible {
        let lhs: Int
        let rhs: Int

        init(_ lhs: Int, _ rhs: Int) {
            self.lhs = lhs
            self.rhs = rhs
        }

        var description: String { return "(\(lhs), \(rhs))" }
    }

    /// Publishes 2, 1, 4, 6, 15, 8, `.finished`, 7, 32.
    /// Uses `Int.trailingZeroBitCount` for comparing values.
    /// Therefore, for the passed comparator 8 is max, 1 is min.
    private static func testBasicBehavior<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        expectedResult: Int,
        semantics: ComparisonSemantics,
        countComparatorCalls: Bool = true,
        _ makeOperator: (CustomPublisher, @escaping (Int, Int) -> Bool) -> Operator
    ) where Operator.Output == Int {

        var comparisonHistory = [ComparisonHistoryElement]()

        func comparator(_ lhs: Int, _ rhs: Int) -> Bool {
            comparisonHistory.append(.init(lhs, rhs))

            // Some custom logic to make sure the publisher doesn't use '<'.
            return lhs.trailingZeroBitCount < rhs.trailingZeroBitCount
        }

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(1),
            receiveValueDemand: .none,
            createSut: { makeOperator($0, comparator) }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])

        XCTAssertEqual(helper.publisher.send(2), .none) // trailingZeroBitCount = 1
        XCTAssertEqual(helper.publisher.send(1), .none) // trailingZeroBitCount = 0
        XCTAssertEqual(helper.publisher.send(4), .none) // trailingZeroBitCount = 2
        XCTAssertEqual(helper.publisher.send(6), .none) // trailingZeroBitCount = 1
        XCTAssertEqual(helper.publisher.send(15), .none) // trailingZeroBitCount = 0
        XCTAssertEqual(helper.publisher.send(8), .none) // trailingZeroBitCount = 3
        XCTAssertEqual(helper.publisher.send(12), .none) // trailingZeroBitCount = 2

        if countComparatorCalls {
            switch semantics {
            case .max:
                XCTAssertEqual(comparisonHistory, [.init(2, 1),
                                                   .init(2, 4),
                                                   .init(4, 6),
                                                   .init(4, 15),
                                                   .init(4, 8),
                                                   .init(8, 12)])
            case .min:
                XCTAssertEqual(comparisonHistory, [.init(1, 2),
                                                   .init(4, 1),
                                                   .init(6, 1),
                                                   .init(15, 1),
                                                   .init(8, 1),
                                                   .init(12, 1)])
            }
        }

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(expectedResult),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(7), .none) // trailingZeroBitCount = 0
        XCTAssertEqual(helper.publisher.send(32), .none) // trailingZeroBitCount = 5

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(expectedResult),
                                                 .completion(.finished)])

        if countComparatorCalls {
            XCTAssertEqual(comparisonHistory.count, 6)
        }
    }
}
