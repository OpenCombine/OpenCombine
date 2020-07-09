//
//  ContainsTests.swift
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
final class ContainsTests: XCTestCase {

    // MARK: - Contains

    func testContainsAllElementsNotSatisfyPredicate() {
        AllSatisfyTests.testAllElementsSatisfyPredicate(
            expectedSubscription: "Contains",
            expectedResult: false,
            countPredicateCalls: false,
            { upstream, _ in upstream.contains(Int.max) }
        )
    }

    func testContainsContainsElementSatisfyingPredicate() {
        AllSatisfyTests.testContainsElementNotSatisfyingPredicate(
            expectedSubscription: "Contains",
            expectedResult: true,
            countPredicateCalls: false,
            { upstream, _ in upstream.contains(7) }
        )
    }

    func testContainsUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Contains",
                                                  { $0.contains(0) })
    }

    func testContainsUpstreamFinishesImmediately() {
        ReduceTests
            .testUpstreamFinishesImmediately(expectedSubscription: "Contains",
                                             expectedResult: false,
                                             { $0.contains(0) })
    }

    func testContainsCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.contains(0) }
    }

    func testContainsRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.contains(0) }
    }

    func testContainsReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "Contains",
            expectedResult: .earlyCompletion(true),
            { $0.contains(0) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "Contains",
            expectedResult: .normalCompletion(false),
            { $0.contains(1) }
        )
    }

    func testContainsReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.contains(0) })
    }

    func testContainsReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.contains(0) }
        )
    }

    func testContainsRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.contains(0) })
    }

    func testContainsCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.contains(0) })
    }

    func testContainsLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.contains(31) })
    }

    func testContainsReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Contains",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "Contains",
                           { $0.contains(31) })
    }

    // MARK: - ContainsWhere

    func testContainsWhereAllElementsNotSatisfyPredicate() {
        // ContainsWhere is just the negation of AllSatisfy
        // evaluated with negated predicate

        // "Doesn't contain an element not satisfying the predicate"
        AllSatisfyTests.testAllElementsSatisfyPredicate(
            expectedSubscription: "ContainsWhere",
            expectedResult: false,
            { upstream, predicate in upstream.contains { !predicate($0) } }
        )
    }

    func testContainsWhereContainsElementSatisfyingPredicate() {
        // ContainsWhere is just the negation of AllSatisfy
        // evaluated with negated predicate
        AllSatisfyTests.testContainsElementNotSatisfyingPredicate(
            expectedSubscription: "ContainsWhere",
            expectedResult: true,
            { upstream, predicate in upstream.contains { !predicate($0) } }
        )
    }

    func testContainsWhereUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(
            expectedSubscription: "ContainsWhere",
            { $0.contains(where: shouldNotBeCalled()) }
        )
    }

    func testContainsWhereUpstreamFinishesImmediately() {
        ReduceTests
            .testUpstreamFinishesImmediately(
                expectedSubscription: "ContainsWhere",
                expectedResult: false,
                { $0.contains(where: shouldNotBeCalled()) }
        )
    }

    func testContainsWhereCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled {
            $0.contains(where: shouldNotBeCalled())
        }
    }

    func testContainsWhereRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.contains(where: shouldNotBeCalled())
        }
    }

    func testContainsWhereReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "ContainsWhere",
            expectedResult: .earlyCompletion(true),
            { $0.contains { $0 == 0 } }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "ContainsWhere",
            expectedResult: .normalCompletion(false),
            { $0.contains { $0 > 0 } }
        )
    }

    func testContainsWhereReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.contains(where: shouldNotBeCalled()) })
    }

    func testContainsWhereReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.contains(where: shouldNotBeCalled()) }
        )
    }

    func testContainsWhereRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.contains(where: shouldNotBeCalled()) })
    }

    func testContainsWhereCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.contains(where: shouldNotBeCalled()) })
    }

    func testContainsWhereLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.contains { _ in true } })
    }

    func testContainsWhereReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "ContainsWhere",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "ContainsWhere",
                           { $0.contains(where: shouldNotBeCalled()) })
    }

    // MARK: - TryContainsWhere

    func testTryContainsWhereAllElementsNotSatisfyPredicate() {
        // TryContainsWhere is just the negation of TryAllSatisfy
        // evaluated with negated predicate

        // "Doesn't contain an element not satisfying the predicate"
        AllSatisfyTests.testAllElementsSatisfyPredicate(
            expectedSubscription: "TryContainsWhere",
            expectedResult: false,
            { upstream, predicate in upstream.tryContains { !predicate($0) } }
        )
    }

    func testTryContainsWhereContainsElementSatisfyingPredicate() {
        // TryContainsWhere is just the negation of TryAllSatisfy
        // evaluated with negated predicate
        AllSatisfyTests.testContainsElementNotSatisfyingPredicate(
            expectedSubscription: "TryContainsWhere",
            expectedResult: true,
            { upstream, predicate in upstream.tryContains { !predicate($0) } }
        )
    }

    func testFailureBecauseOfThrow() throws {

        func predicate(_ input: Int) throws -> Bool {
            if input == 3 {
                throw TestingError.oops
            }
            return input > 3
        }

        try ReduceTests
            .testFailureBecauseOfThrow(expectedSubscription: "TryContainsWhere",
                                       expectedFailure: TestingError.oops,
                                       { $0.tryContains(where: predicate) })
    }

    func testTryContainsWhereUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(
            expectedSubscription: "TryContainsWhere",
            { $0.tryContains(where: shouldNotBeCalled()) }
        )
    }

    func testTryContainsWhereUpstreamFinishesImmediately() {
        ReduceTests .testUpstreamFinishesImmediately(
            expectedSubscription: "TryContainsWhere",
            expectedResult: false,
            { $0.tryContains(where: shouldNotBeCalled()) })
    }

    func testTryContainsWhereCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled {
            $0.tryContains(where: shouldNotBeCalled())
        }
    }

    func testTryContainsWhereRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.tryContains(where: shouldNotBeCalled())
        }
    }

    func testTryContainsWhereReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryContainsWhere",
            expectedResult: .earlyCompletion(true),
            { $0.tryContains { $0 == 0 } }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryContainsWhere",
            expectedResult: .normalCompletion(false),
            { $0.tryContains { $0 > 0 } }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryContainsWhere",
            expectedResult: .failure(TestingError.oops),
            { $0.tryContains { _ in throw TestingError.oops } }
        )
    }

    func testTryContainsWhereReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.tryContains(where: shouldNotBeCalled()) })
    }

    func testTryContainsWhereReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryContains(where: shouldNotBeCalled()) }
        )
    }

    func testTryContainsWhereRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryContains(where: shouldNotBeCalled()) })
    }

    func testTryContainsWhereCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.tryContains(where: shouldNotBeCalled()) })
    }

    func testTryContainsWhereLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryContains { _ in true } })
    }

    func testTryContainsWhereReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryContainsWhere",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "TryContainsWhere",
                           { $0.tryContains(where: shouldNotBeCalled()) })
    }
}
