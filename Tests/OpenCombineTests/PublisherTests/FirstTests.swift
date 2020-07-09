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

    // MARK: - First

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
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "First") {
            $0.first()
        }
    }

    func testFirstFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "First",
                                                    expectedResult: nil) {
            $0.first()
        }
    }

    func testFirstRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.first() }
    }

    func testFirstReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "First",
            expectedResult: .earlyCompletion(0),
            { $0.first() }
        )
    }

    func testFirstReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.first() })
    }

    func testFirstReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.first() }
        )
    }

    func testFirstRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.first() })
    }

    func testFirstCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.first() })
    }

    func testFirstLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.first() })
    }

    func testFirstCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.first() }
    }

    func testFirstReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "First",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "First",
                           { $0.first() })
    }

    // MARK: - FirstWhere

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
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "TryFirst") {
            $0.first(where: { $0 > 2 })
        }
    }

    func testFirstWhereFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "TryFirst",
                                                    expectedResult: nil) {
            $0.first(where: { $0 > 2 })
        }
    }

    func testFirstWhereRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.first(where: { $0 > 0 })
        }
    }

    func testFirstWhereReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryFirst",
            expectedResult: .normalCompletion(nil),
            { $0.first(where: { _ in false }) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryFirst",
            expectedResult: .earlyCompletion(0),
            { $0.first(where: { _ in true }) }
        )
    }

    func testFirstWhereReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.first(where: shouldNotBeCalled()) })
    }

    func testFirstWhereReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.first(where: shouldNotBeCalled()) }
        )
    }

    func testFirstWhereRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.first(where: shouldNotBeCalled()) })
    }

    func testFirstWhereCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.first(where: shouldNotBeCalled()) })
    }

    func testFirstWhereLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.first { $0 > 1 } })
    }

    func testFirstWhereCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.first(where: { $0 > 2 }) }
    }

    func testFirstWhereReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryFirst",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "TryFirst",
                           { $0.first(where: { $0 > 2 }) })
    }

    // MARK: - TryFirstWhere

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
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "TryFirstWhere") {
            $0.tryFirst(where: { $0 > 2 })
        }
    }

    func testTryFirstWhereFinishesImmediately() {
        ReduceTests
            .testUpstreamFinishesImmediately(expectedSubscription: "TryFirstWhere",
                                             expectedResult: nil) {
                $0.tryFirst(where: { $0 > 2 })
            }
    }

    func testTryFirstWhereRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription {
            $0.tryFirst(where: { $0 > 0 })
        }
    }

    func testTryFirstWhereFinishesWhenErrorThrown() throws {

        func predicate(_ input: Int) throws -> Bool {
            if input == 3 {
                throw TestingError.oops
            }
            return input > 3
        }

        try ReduceTests.testFailureBecauseOfThrow(expectedSubscription: "TryFirstWhere",
                                                  expectedFailure: TestingError.oops,
                                                  { $0.tryFirst(where: predicate) })
    }

    func testTryFirstWhereReceiveSubscriptionTwice() throws {
        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryFirstWhere",
            expectedResult: .normalCompletion(nil),
            { $0.tryFirst(where: { _ in false }) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryFirstWhere",
            expectedResult: .earlyCompletion(0),
            { $0.tryFirst(where: { _ in true }) }
        )

        try ReduceTests.testReceiveSubscriptionTwice(
            expectedSubscription: "TryFirstWhere",
            expectedResult: .failure(TestingError.oops),
            { $0.tryFirst(where: { _ in throw TestingError.oops }) }
        )
    }

    func testTryFirstWhereReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.tryFirst(where: shouldNotBeCalled()) })
    }

    func testTryFirstWhereReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryFirst(where: shouldNotBeCalled()) }
        )
    }

    func testTryFirstWhereRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryFirst(where: shouldNotBeCalled()) })
    }

    func testTryFirstWhereCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.tryFirst(where: shouldNotBeCalled()) })
    }

    func testTryFirstWhereLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryFirst { $0 > 1 } })
    }

    func testTryFirstCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.tryFirst(where: { $0 > 2 }) }
    }

    func testTryFirstWhereReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryFirstWhere",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "TryFirstWhere",
                           { $0.tryFirst(where: { $0 > 2 }) })
    }
}
