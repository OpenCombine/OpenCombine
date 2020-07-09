//
//  PrefixWhileTests.swift
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
final class PrefixWhileTests: XCTestCase {

    // MARK: - PrefixWhile

    func testPrefixWhileBasicBehavior() {
        var counter = 0

        func predicate(_ value: Int) -> Bool {
            counter += 1
            return value < 4
        }

        FilterTests.testBasicBehavior(input: [(1, expectedDemand: .max(4)),
                                              (2, expectedDemand: .max(4)),
                                              (3, expectedDemand: .max(4)),
                                              (4, expectedDemand: .none),
                                              (5, expectedDemand: .none),
                                              (6, expectedDemand: .none)],
                                      expectedSubscription: "PrefixWhile",
                                      expectedOutput: [1, 2, 3],
                                      { $0.prefix(while: predicate) })
        XCTAssertEqual(counter, 4)
    }

    func testPrefixWhileUpstreamFinishesImmediately() {
        FilterTests.testUpstreamFinishesImmediately(
            expectedSubscription: "PrefixWhile",
            { $0.prefix(while: shouldNotBeCalled()) }
        )
    }

    func testPrefixWhileUpstreamFinishesWithError() {
        FilterTests.testUpstreamFinishesWithError(
            expectedSubscription: "PrefixWhile",
            { $0.prefix(while: shouldNotBeCalled()) }
        )
    }

    func testPrefixWhileDemand() {
        PrefixWhileTests.testDemand { publisher, filter in
            publisher.prefix(while: filter)
        }
    }

    func testPrefixWhileNoDemand() {
        FilterTests.testNoDemand { $0.prefix(while: shouldNotBeCalled()) }
    }

    func testPrefixWhileCancelAlreadyCancelled() throws {
        try FilterTests.testCancelAlreadyCancelled(
            expectedSubscription: "PrefixWhile",
            { $0.prefix(while: shouldNotBeCalled()) }
        )
    }

    func testPrefixWhileReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .crash,
                                           { $0.prefix(while: shouldNotBeCalled()) })
    }

    func testPrefixWhileReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .crash,
            { $0.prefix(while: shouldNotBeCalled()) }
        )
    }

    func testPrefixWhileRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: true,
                                      { $0.prefix(while: shouldNotBeCalled()) })
    }

    func testPrefixWhileCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.cancelled]),
                                     { $0.prefix(while: shouldNotBeCalled()) })
    }

    func testPrefixWhileReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.prefix(while: shouldNotBeCalled()) }
    }

    func testPrefixWhileLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.prefix { $0.isMultiple(of: 2) } })
    }

    func testPrefixWhileReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "PrefixWhile",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase"))
                           ),
                           playgroundDescription: "PrefixWhile",
                           { $0.prefix(while: shouldNotBeCalled()) })
    }

    // MARK: - TryPrefixWhile

    func testTryPrefixWhileBasicBehavior() {
        var counter = 0

        func predicate(_ value: Int) throws -> Bool {
            counter += 1
            if value == 5 {
                throw TestingError.oops
            }
            return value < 4
        }

        FilterTests.testBasicBehavior(input: [(1, expectedDemand: .max(4)),
                                              (2, expectedDemand: .max(4)),
                                              (3, expectedDemand: .max(4)),
                                              (4, expectedDemand: .none),
                                              (5, expectedDemand: .none),
                                              (6, expectedDemand: .none)],
                                      expectedSubscription: "TryPrefixWhile",
                                      expectedOutput: [1, 2, 3],
                                      { $0.tryPrefix(while: predicate) })
        XCTAssertEqual(counter, 4)
    }

    func testTryPrefixWhileCompletesWithErrorWhenThrown() {
        var counter = 0
        func predicate(_ value: Int) throws -> Bool {
            counter += 1
            if value == 5 {
                throw TestingError.oops
            }
            return value.isMultiple(of: 2)
        }

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(3),
                                        receiveValueDemand: .max(42),
                                        createSut: { $0.tryPrefix(while: predicate) })

        XCTAssertEqual(helper.publisher.send(2), .max(42))
        XCTAssertEqual(helper.publisher.send(4), .max(42))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.publisher.send(5), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])

        XCTAssertEqual(helper.publisher.send(6), .none)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))

        helper.downstreamSubscription?.request(.max(1000))
        helper.downstreamSubscription?.cancel()

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryPrefixWhile"),
                        .value(2),
                        .value(4),
                        .completion(.failure(TestingError.oops))])

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])
    }

    func testTryPrefixWhileUpstreamFinishesImmediately() {
        FilterTests.testUpstreamFinishesImmediately(
            expectedSubscription: "TryPrefixWhile",
            { $0.tryPrefix(while: shouldNotBeCalled()) }
        )
    }

    func testTryPrefixWhileUpstreamFinishesWithError() {
        FilterTests.testUpstreamFinishesWithError(
            expectedSubscription: "TryPrefixWhile",
            { $0.tryPrefix(while: shouldNotBeCalled()) }
        )
    }

    func testTryPrefixWhileDemand() {
        PrefixWhileTests.testDemand { publisher, filter in
            publisher.tryPrefix(while: filter)
        }
    }

    func testTryPrefixWhileNoDemand() {
        FilterTests.testNoDemand { $0.tryPrefix(while: shouldNotBeCalled()) }
    }

    func testTryPrefixWhileCancelAlreadyCancelled() throws {
        try FilterTests.testCancelAlreadyCancelled(
            expectedSubscription: "TryPrefixWhile",
            { $0.tryPrefix(while: shouldNotBeCalled()) }
        )
    }

    func testTryPrefixWhileReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .crash,
                                           { $0.tryPrefix(while: shouldNotBeCalled()) })
    }

    func testTryPrefixWhileReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .crash,
            { $0.tryPrefix(while: shouldNotBeCalled()) }
        )
    }

    func testTryPrefixWhileRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: true,
                                      { $0.tryPrefix(while: shouldNotBeCalled()) })
    }

    func testTryPrefixWhileCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.cancelled]),
                                     { $0.tryPrefix(while: shouldNotBeCalled()) })
    }

    func testTryPrefixWhileReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.tryPrefix(while: shouldNotBeCalled()) }
    }

    func testTryPrefixWhileLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryPrefix { $0.isMultiple(of: 2) } })
    }

    func testTryPrefixWhileReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "TryPrefixWhile",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase"))
                           ),
                           playgroundDescription: "TryPrefixWhile",
                           { $0.tryPrefix(while: shouldNotBeCalled()) })
    }

    // MARK: - Generic tests

    private static func testDemand<Operator: Publisher>(
        _ makeOperator: (CustomPublisherBase<Int, Error>,
                        _ filter: @escaping (Int) -> Bool) -> Operator
    )
        where Operator.Output: Equatable, Operator.Failure == Error
    {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<Int, Error>(subscription: subscription)
        let operatorPublisher = makeOperator(publisher, { $0.isMultiple(of: 2) })
        var downstreamSubscription: Subscription?

        var demandOnReceiveValue = Subscribers.Demand.max(2)
        let tracking = TrackingSubscriberBase<Operator.Output, Error>(
            receiveSubscription: {
                $0.request(.max(3))
                downstreamSubscription = $0
            },
            receiveValue: { _ in demandOnReceiveValue }
        )

        operatorPublisher.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(subscription.history, [.requested(.max(3))])
        // unsatisfied demand = 3

        XCTAssertEqual(publisher.send(2), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(3))])
        // unsatisfied demand = 3 - 1 + 2 = 4

        demandOnReceiveValue = Subscribers.Demand.max(4)
        XCTAssertEqual(publisher.send(4), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(3))])
        // unsatisfied demand = 4 - 1 + 4 = 7

        demandOnReceiveValue = .none
        XCTAssertEqual(publisher.send(6), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(3))])
        // unsatisfied demand = 7 - 1 = 6

        downstreamSubscription?.request(.max(15))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.max(3)),
                                              .requested(.max(15)),
                                              .requested(.max(5))])
        // unsatisfied demand = 6 + 15 + 5 = 26

        demandOnReceiveValue = .max(121)
        XCTAssertEqual(publisher.send(3), .none)
        XCTAssertEqual(subscription.history, [.requested(.max(3)),
                                              .requested(.max(15)),
                                              .requested(.max(5)),
                                              .cancelled])

        downstreamSubscription?.request(.max(3))
        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        XCTAssertEqual(subscription.history, [.requested(.max(3)),
                                              .requested(.max(15)),
                                              .requested(.max(5)),
                                              .cancelled])
    }
}
