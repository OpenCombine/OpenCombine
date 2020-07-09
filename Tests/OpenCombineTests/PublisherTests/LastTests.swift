//
//  LastTests.swift
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
final class LastTests: XCTestCase {

    // MARK: - Last

    func testLastFinishesAndReturnsLastItem() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(3),
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.last() })

        XCTAssertEqual(helper.tracking.history, [.subscription("Last")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(25), .none)
        XCTAssertEqual(helper.publisher.send(42), .none)
        XCTAssertEqual(helper.publisher.send(10), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("Last")])

        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history, [.subscription("Last"),
                                                 .value(10),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(73), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("Last"),
                                                 .value(10),
                                                 .completion(.finished)])
    }

    func testLastFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Last") {
            $0.last()
        }
    }

    func testLastFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "Last",
                                                    expectedResult: nil) {
            $0.last()
        }
    }

    func testLastRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.last() }
    }

    func testLastReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "Last",
            expectedResult: .normalCompletion(0),
            { $0.last() }
        )
    }

    func testLastReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.last() })
    }

    func testLastReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.last() }
        )
    }

    func testLastRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.last() })
    }

    func testLastCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.last() })
    }

    func testLastLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.last() })
    }

    func testLastCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.last() }
    }

    func testLastReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Last",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "Last",
                           { $0.last() })
    }

    // MARK: - LastWhere

    func testLastWhereDemand() throws {

        var firedCounter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: {
                $0.last {
                    firedCounter += 1
                    return $0 > 1
                }
            }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere")])
        XCTAssertEqual(firedCounter, 4)

        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere")])

        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere"),
                                                 .value(2),
                                                 .completion(.finished)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testLastWhereFinishesAndReturnsLastMatchingItem() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(5),
            receiveValueDemand: .max(1),
            createSut: { $0.last(where: { $0 < 3 }) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere")])

        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere")])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere")])

        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere"),
                                                 .value(2),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("LastWhere"),
                                                 .value(2),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testLastWhereFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "LastWhere") {
            $0.last(where: { $0 > 2 })
        }
    }

    func testLastWhereFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "LastWhere",
                                                    expectedResult: nil) {
            $0.last(where: { $0 > 2 })
        }
    }

    func testLastWhereRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.last(where: { $0 > 0 })
        }
    }

    func testLastWhereReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "LastWhere",
            expectedResult: .normalCompletion(nil),
            { $0.last(where: { _ in false }) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "LastWhere",
            expectedResult: .normalCompletion(0),
            { $0.last(where: { _ in true }) }
        )
    }

    func testLastWhereReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.last(where: shouldNotBeCalled()) })
    }

    func testLastWhereReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.last(where: shouldNotBeCalled()) }
        )
    }

    func testLastWhereRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.last(where: shouldNotBeCalled()) })
    }

    func testLastWhereCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.last(where: shouldNotBeCalled()) })
    }

    func testLastWhereLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.last { $0 > 1 } })
    }

    func testLastWhereCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.last(where: { $0 > 2 }) }
    }

    func testLastWhereReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "LastWhere",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "LastWhere",
                           { $0.last(where: { $0 > 2 }) })
    }

    // MARK: - TryLastWhere

    func testTryLastWhereDemand() throws {

        var firedCounter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: {
                $0.tryLast {
                    firedCounter += 1
                    return $0 > 1
                }
            }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(0), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere")])
        XCTAssertEqual(firedCounter, 4)

        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere")])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere"),
                                                 .value(2),
                                                 .completion(.finished)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testTryLastWhereFinishesAndReturnsLastMatchingItem() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(5),
            receiveValueDemand: .max(1),
            createSut: { $0.tryLast(where: { $0 < 3 }) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere")])

        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere")])

        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere")])

        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere"),
                                                 .value(2),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("TryLastWhere"),
                                                 .value(2),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testTryLastWhereFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "TryLastWhere") {
            $0.tryLast(where: { $0 > 2 })
        }
    }

    func testTryLastWhereFinishesImmediately() {
        ReduceTests
            .testUpstreamFinishesImmediately(expectedSubscription: "TryLastWhere",
                                             expectedResult: nil) {
                $0.tryLast(where: { $0 > 2 })
            }
    }

    func testTryLastWhereRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.tryLast(where: { $0 > 0 })
        }
    }

    func testTryLastWhereFinishesWhenErrorThrown() throws {

        func predicate(_ input: Int) throws -> Bool {
            if input == 3 {
                throw TestingError.oops
            }
            return input < 3
        }

        try ReduceTests.testFailureBecauseOfThrow(expectedSubscription: "TryLastWhere",
                                                  expectedFailure: TestingError.oops,
                                                  { $0.tryLast(where: predicate) })
    }

    func testTryLastWhereReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryLastWhere",
            expectedResult: .normalCompletion(nil),
            { $0.tryLast(where: { _ in false }) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryLastWhere",
            expectedResult: .normalCompletion(0),
            { $0.tryLast(where: { _ in true }) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryLastWhere",
            expectedResult: .failure(TestingError.oops),
            { $0.tryLast(where: { _ in throw TestingError.oops }) }
        )
    }

    func testTryLastWhereReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.tryLast(where: shouldNotBeCalled()) })
    }

    func testTryLastWhereReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryLast(where: shouldNotBeCalled()) }
        )
    }

    func testTryLastWhereRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryLast(where: shouldNotBeCalled()) })
    }

    func testTryLastWhereCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.tryLast(where: shouldNotBeCalled()) })
    }

    func testTryLastWhereLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryLast { $0 > 1 } })
    }

    func testTryLastCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.tryLast(where: { $0 > 2 }) }
    }

    func testTryLastWhereReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryLastWhere",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "TryLastWhere",
                           { $0.tryLast(where: { $0 > 2 }) })
    }
}
