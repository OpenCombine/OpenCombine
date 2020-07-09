//
//  DropWhileTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class DropWhileTests: XCTestCase {

    // MARK: - DropWhile

    func testDropWhileBasicBehavior() {
        DropWhileTests.testBasicBehavior(
            expectedSubscription: "DropWhile",
            { publisher, predicate in publisher.drop(while: predicate) }
        )
    }

    func testDropWhileDemand() throws {
        try DropWhileTests.testDemand { publisher, predicate in
            publisher.drop(while: predicate)
        }
    }

    func testDropWhileCrashesOnZeroRequest() {
        testCrashesOnEmptyRequest { $0.drop(while: shouldNotBeCalled()) }
    }

    func testDropWhileCompletion() {
        DropWhileTests.testImmediateCompletion(expectedSubscription: "DropWhile",
                                               { $0.drop(while: shouldNotBeCalled()) })
    }

    func testDropWhileReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.drop(while: shouldNotBeCalled()) })
    }

    func testDropWhileReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.drop(while: shouldNotBeCalled()) }
        )
    }

    func testDropWhileRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.drop(while: shouldNotBeCalled()) })
    }

    func testDropWhileCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.drop(while: shouldNotBeCalled()) })
    }

    func testDropWhileReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.drop(while: shouldNotBeCalled()) }
    }

    func testDropWhileCancelAlreadyCancelled() throws {
        try DropWhileTests.testCancelAlreadyCancelled(
            expectedSubscription: "DropWhile",
            { $0.drop(while: shouldNotBeCalled()) }
        )
    }

    func testDropWhileLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.drop(while: { _ in false }) })
    }

    func testDropWhileReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "DropWhile",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "DropWhile",
                           { $0.drop(while: shouldNotBeCalled()) })
    }

    // MARK: - TryDropWhile

    func testTryDropWhileBasicBehavior() {
        DropWhileTests.testBasicBehavior(
            expectedSubscription: "TryDropWhile",
            { publisher, predicate in publisher.tryDrop(while: predicate) }
        )
    }

    func testTryDropWhileDemand() throws {
        try DropWhileTests.testDemand { publisher, predicate in
            publisher.tryDrop(while: predicate)
        }
    }

    func testTryDropWhileCrashesOnZeroRequest() {
        testCrashesOnEmptyRequest { $0.tryDrop(while: shouldNotBeCalled()) }
    }

    func testTryDropWhileCompletion() {
        DropWhileTests.testImmediateCompletion(expectedSubscription: "TryDropWhile",
                                               { $0.tryDrop(while: shouldNotBeCalled()) })
    }

    func testTryDropWhileReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.tryDrop(while: shouldNotBeCalled()) })
    }

    func testTryDropWhileReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryDrop(while: shouldNotBeCalled()) }
        )
    }

    func testTryDropWhileRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryDrop(while: shouldNotBeCalled()) })
    }

    func testTryDropWhileCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.tryDrop(while: shouldNotBeCalled()) })
    }

    func testTryDropWhileReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.tryDrop(while: shouldNotBeCalled()) }
    }

    func testTryDropWhileCancelAlreadyCancelled() throws {
        try DropWhileTests.testCancelAlreadyCancelled(
            expectedSubscription: "TryDropWhile",
            { $0.tryDrop(while: shouldNotBeCalled()) }
        )
    }

    func testTryDropWhileFailureBecauseOfThrow() {
        var counter = 0 // How many times the predicate is called?

        let predicate: (Int) throws -> Bool = {
            counter += 1
            if $0 == 100 {
                throw "too much" as TestingError
            }
            return $0.isMultiple(of: 2)
        }

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.tryDrop(while: predicate) })

        XCTAssertEqual(helper.tracking.history, [.subscription("TryDropWhile")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(1))
        XCTAssertEqual(helper.publisher.send(100), .none)
        XCTAssertEqual(helper.publisher.send(9), .none)
        XCTAssertEqual(helper.publisher.send(8), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure("too much" as TestingError))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure("too much" as TestingError))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        XCTAssertEqual(counter, 3)
    }

    func testTryDropWhileFailureOnCompletion() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: { $0.tryDrop(while: shouldNotBeCalled()) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryDropWhile")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testTryDropWhileSuccess() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .none,
            createSut: { $0.tryDrop { $0.isMultiple(of: 2) } }
        )

        XCTAssertEqual(helper.publisher.send(0), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(5), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .value(3),
                        .value(4),
                        .value(5)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.publisher.send(8), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .value(3),
                        .value(4),
                        .value(5),
                        .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
    }

    func testTryDropWhileLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryDrop(while: { _ in false }) })
    }

    func testTryDropWhileReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "TryDropWhile",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "TryDropWhile",
                           { $0.tryDrop(while: shouldNotBeCalled()) })
    }

    // MARK: - Generic

    private static func testBasicBehavior<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisher, @escaping (Int) -> Bool) -> Operator
    ) where Operator.Output == Int {
        var counter = 0 // How many times the predicate was called?

        let predicate: (Int) -> Bool = { counter += 1; return $0.isMultiple(of: 2) }

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { makeOperator($0, predicate) })
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(1))
        XCTAssertEqual(helper.publisher.send(6), .max(1))
        XCTAssertEqual(helper.publisher.send(7), .none)
        XCTAssertEqual(helper.publisher.send(8), .none)
        XCTAssertEqual(helper.publisher.send(9), .none)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(10), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .value(7),
                                                 .value(8),
                                                 .value(9),
                                                 .completion(.finished)])

        XCTAssertEqual(counter, 4)
    }

    private static func testDemand<Operator: Publisher>(
        _ makeOperator: (CustomPublisher, @escaping (Int) -> Bool) -> Operator
    ) throws {

        let predicate: (Int) -> Bool = { $0.isMultiple(of: 2) }

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(42),
                                        receiveValueDemand: .max(4),
                                        createSut: { makeOperator($0, predicate) })

        XCTAssertEqual(helper.subscription.history, [.requested(.max(42))])

        XCTAssertEqual(helper.publisher.send(0), .max(1))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42))])

        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42))])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(95))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.max(95)),
                                                     .requested(.max(5))])

        XCTAssertEqual(helper.publisher.send(3), .max(4))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.max(95)),
                                                     .requested(.max(5))])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(121))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .requested(.max(121))])

        XCTAssertEqual(helper.publisher.send(7), .max(4))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .requested(.max(121))])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .requested(.max(121)),
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(50))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(42)),
                                                     .requested(.max(95)),
                                                     .requested(.max(5)),
                                                     .requested(.max(121)),
                                                     .cancelled])

        XCTAssertEqual(helper.publisher.send(8), .none)
    }

    private static func testImmediateCompletion<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisher) -> Operator
    ) where Operator.Output == Int {

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: makeOperator)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.finished)])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.finished)])
    }

    private func testCrashesOnEmptyRequest<Operator: Publisher>(
        _ makeOperator: (CustomPublisher) -> Operator
    ) where Operator.Output == Int {

        let publisher = CustomPublisher(subscription: CustomSubscription())
        let drop = makeOperator(publisher)
        let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>(
            receiveSubscription: { $0.request(.none) }
        )
        assertCrashes {
            drop.subscribe(tracking)
        }
    }

    private static func testCancelAlreadyCancelled<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisher) -> Operator
    ) throws where Operator.Output == Int {

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: makeOperator)

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
    }
}
