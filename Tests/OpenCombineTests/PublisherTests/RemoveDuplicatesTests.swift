//
//  RemoveDuplicatesTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.11.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class RemoveDuplicatesTests: XCTestCase {

    // MARK: - RemoveDuplicates

    func testRemoveDuplicatesBasicBehavior() {

        var counter = 0

        func predicate1(lhs: Int, rhs: Int) -> Bool {
            counter += 1
            return lhs >= rhs
        }

        // swiftlint:disable comma
        FilterTests.testBasicBehavior(input: [(1,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(1)),
                                              (50, expectedDemand: .max(4)),
                                              (30, expectedDemand: .max(1)),
                                              (10, expectedDemand: .max(1)),
                                              (-1, expectedDemand: .max(1)),
                                              (51, expectedDemand: .max(4)),
                                              (52, expectedDemand: .max(4))],
                                      expectedSubscription: "RemoveDuplicates",
                                      expectedOutput: [1, 2, 50, 51, 52],
                                      { $0.removeDuplicates(by: predicate1) })
        // swiftlint:enable comma

        XCTAssertEqual(counter, 8)

        func predicate2(lhs: Int, rhs: Int) -> Bool {
            counter += 1
            return lhs > rhs
        }

        // swiftlint:disable comma
        FilterTests.testBasicBehavior(input: [(1,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(4)),
                                              (50, expectedDemand: .max(4)),
                                              (30, expectedDemand: .max(1)),
                                              (10, expectedDemand: .max(1)),
                                              (-1, expectedDemand: .max(1)),
                                              (51, expectedDemand: .max(4)),
                                              (52, expectedDemand: .max(4))],
                                      expectedSubscription: "RemoveDuplicates",
                                      expectedOutput: [1, 2, 2, 50, 51, 52],
                                      { $0.removeDuplicates(by: predicate2) })
        // swiftlint:enable comma

        XCTAssertEqual(counter, 16)

        // swiftlint:disable comma
        FilterTests.testBasicBehavior(input: [(1,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(1)),
                                              (50, expectedDemand: .max(4)),
                                              (30, expectedDemand: .max(4)),
                                              (10, expectedDemand: .max(4)),
                                              (-1, expectedDemand: .max(4)),
                                              (51, expectedDemand: .max(4)),
                                              (52, expectedDemand: .max(4))],
                                      expectedSubscription: "RemoveDuplicates",
                                      expectedOutput: [1, 2, 50, 30, 10, -1, 51, 52],
                                      { $0.removeDuplicates() })
        // swiftlint:enable comma
    }

    func testRemoveDuplicatesUpstreamFinishesImmediately() {
        FilterTests.testUpstreamFinishesImmediately(
            expectedSubscription: "RemoveDuplicates",
            { $0.removeDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testRemoveDuplicatesUpstreamFinishesWithError() {
        FilterTests.testUpstreamFinishesWithError(
            expectedSubscription: "RemoveDuplicates",
            { $0.removeDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testRemoveDuplicatesDemand() {
        RemoveDuplicatesTests.testDemand { publisher, comparator in
            publisher.removeDuplicates(by: comparator)
        }
    }

    func testRemoveDuplicatesNoDemand() {
        FilterTests.testNoDemand { $0.removeDuplicates(by: shouldNotBeCalled()) }
    }

    func testRemoveDuplicatesCancelAlreadyCancelled() throws {
        try FilterTests.testCancelAlreadyCancelled(
            expectedSubscription: "RemoveDuplicates",
            { $0.removeDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testRemoveDuplicatesReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .crash,
            { $0.removeDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testRemoveDuplicatesCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .crash,
            { $0.removeDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testRemoveDuplicatesRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: true,
                                      { $0.removeDuplicates(by: shouldNotBeCalled()) })
    }

    func testRemoveDuplicatesCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.cancelled]),
                                     { $0.removeDuplicates(by: shouldNotBeCalled()) })
    }

    func testRemoveDuplicatesReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice {
            $0.removeDuplicates(by: shouldNotBeCalled())
        }
    }

    // TODO: Test a case when the filter closure calls send on the upstream publisher.
    // Is the last value updated at that point?

    func testRemoveDuplicatesLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.removeDuplicates(by: <) })
    }

    func testRemoveDuplicatesReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "RemoveDuplicates",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("last", "nil")
                           ),
                           playgroundDescription: "RemoveDuplicates",
                           { $0.removeDuplicates(by: shouldNotBeCalled()) })
    }

    // MARK: - TryRemoveDuplicates

    func testTryRemoveDuplicatesBasicBehavior() {

        var counter = 0

        func predicate1(lhs: Int, rhs: Int) -> Bool {
            counter += 1
            return lhs >= rhs
        }

        // swiftlint:disable comma
        FilterTests.testBasicBehavior(input: [(1,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(1)),
                                              (50, expectedDemand: .max(4)),
                                              (30, expectedDemand: .max(1)),
                                              (10, expectedDemand: .max(1)),
                                              (-1, expectedDemand: .max(1)),
                                              (51, expectedDemand: .max(4)),
                                              (52, expectedDemand: .max(4))],
                                      expectedSubscription: "TryRemoveDuplicates",
                                      expectedOutput: [1, 2, 50, 51, 52],
                                      { $0.tryRemoveDuplicates(by: predicate1) })
        // swiftlint:enable comma

        XCTAssertEqual(counter, 8)

        func predicate2(lhs: Int, rhs: Int) -> Bool {
            counter += 1
            return lhs > rhs
        }

        // swiftlint:disable comma
        FilterTests.testBasicBehavior(input: [(1,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(4)),
                                              (2,  expectedDemand: .max(4)),
                                              (50, expectedDemand: .max(4)),
                                              (30, expectedDemand: .max(1)),
                                              (10, expectedDemand: .max(1)),
                                              (-1, expectedDemand: .max(1)),
                                              (51, expectedDemand: .max(4)),
                                              (52, expectedDemand: .max(4))],
                                      expectedSubscription: "TryRemoveDuplicates",
                                      expectedOutput: [1, 2, 2, 50, 51, 52],
                                      { $0.tryRemoveDuplicates(by: predicate2) })
        // swiftlint:enable comma

        XCTAssertEqual(counter, 16)
    }

    func testTryRemoveDuplicatesCompletesWithErrorWhenThrown() {
        var counter = 0
        func comparator(lhs: Int, rhs: Int) throws -> Bool {
            counter += 1
            if rhs == 42 {
                throw TestingError.oops
            }
            return lhs == rhs
        }

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(10),
            createSut: { $0.tryRemoveDuplicates(by: comparator) }
        )

        XCTAssertEqual(helper.publisher.send(1), .max(10))
        XCTAssertEqual(helper.publisher.send(2), .max(10))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(1), .max(10))
        XCTAssertEqual(helper.publisher.send(3), .max(10))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.publisher.send(42), .none)
        XCTAssertEqual(helper.publisher.send(42), .none)
        XCTAssertEqual(helper.publisher.send(43), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))

        helper.downstreamSubscription?.request(.max(1000))
        helper.downstreamSubscription?.cancel()

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryRemoveDuplicates"),
                        .value(1),
                        .value(2),
                        .value(1),
                        .value(3),
                        .completion(.failure(TestingError.oops))])

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])
        XCTAssertEqual(counter, 9)
    }

    func testTryRemoveDuplicatesUpstreamFinishesImmediately() {
        FilterTests.testUpstreamFinishesImmediately(
            expectedSubscription: "TryRemoveDuplicates",
            { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testTryRemoveDuplicatesDemand() {
        RemoveDuplicatesTests.testDemand { publisher, comparator in
            publisher.tryRemoveDuplicates(by: comparator)
        }
    }

    func testTryRemoveDuplicatesNoDemand() {
        FilterTests.testNoDemand { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) }
    }

    func testTryRemoveDuplicatesCancelAlreadyCancelled() throws {
        try FilterTests.testCancelAlreadyCancelled(
            expectedSubscription: "TryRemoveDuplicates",
            { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testTryRemoveDuplicatesUpstreamFinishesWithError() {
        FilterTests.testUpstreamFinishesWithError(
            expectedSubscription: "TryRemoveDuplicates",
            { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testTryRemoveDuplicatesReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .crash,
            { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testTryRemoveDuplicatesCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .crash,
            { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) }
        )
    }

    func testTryRemoveDuplicatesRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: true,
                                      { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) })
    }

    func testTryRemoveDuplicatesCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.cancelled]),
                                     { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) })
    }

    func testTryRemoveDuplicatesReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice {
            $0.tryRemoveDuplicates(by: shouldNotBeCalled())
        }
    }

    func testTryRemoveDuplicatesLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryRemoveDuplicates(by: <) })
    }

    func testTryRemoveDuplicatesReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "TryRemoveDuplicates",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("last", "nil")
                           ),
                           playgroundDescription: "TryRemoveDuplicates",
                           { $0.tryRemoveDuplicates(by: shouldNotBeCalled()) })
    }

    // MARK: - Generic tests

    static func testDemand<Operator: Publisher>(
        _ makeOperator: (CustomPublisherBase<Int, Error>,
                        _ comparator: @escaping (Int, Int) -> Bool) -> Operator
    )
        where Operator.Output: Equatable, Operator.Failure == Error
    {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<Int, Error>(subscription: subscription)
        let operatorPublisher = makeOperator(publisher, ==)
        var downstreamSubscription: Subscription?

        var demandOnReceiveValue = Subscribers.Demand.max(3)
        let tracking = TrackingSubscriberBase<Operator.Output, Error>(
            receiveSubscription: {
                $0.request(.max(5))
                downstreamSubscription = $0
            },
            receiveValue: { _ in demandOnReceiveValue }
        )

        operatorPublisher.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 5

        XCTAssertEqual(publisher.send(1), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 5 - 1 + 3 = 7

        demandOnReceiveValue = .max(2)
        XCTAssertEqual(publisher.send(2), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 7 - 1 + 2 = 8

        demandOnReceiveValue = .max(10)
        XCTAssertEqual(publisher.send(3), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 8 - 1 + 10 = 17

        XCTAssertEqual(publisher.send(3), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 17

        XCTAssertEqual(publisher.send(3), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 17

        downstreamSubscription?.request(.max(15))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5))])
        // unsatisfied demand = 17 + 15 + 5 = 37

        demandOnReceiveValue = .none
        XCTAssertEqual(publisher.send(-1), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5))])
        // unsatisfied demand = 37 - 1 + 0 = 36

        demandOnReceiveValue = .max(10)
        XCTAssertEqual(publisher.send(-2), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5))])
        // unsatisfied demand = 36 - 1 + 10 = 45

        XCTAssertEqual(publisher.send(-2), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5))])
        // unsatisfied demand = 45

        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5)),
                                              .cancelled])
        downstreamSubscription?.request(.max(3))
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5)),
                                              .cancelled])
    }
}
