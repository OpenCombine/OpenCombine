//
//  FilterTests.swift
//
//
//  Created by Joseph Spadafora on 6/25/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class FilterTests: XCTestCase {

    // MARK: - Filter

    func testFilterBasicBehavior() {
        var counter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(4),
            createSut: { $0.filter { counter += 1; return $0.isMultiple(of: 2) } }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(4))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(4))
        XCTAssertEqual(helper.publisher.send(5), .max(1))

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(6), .max(4))

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(2),
                                                 .value(4),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .value(6)])
        XCTAssertEqual(counter, 6)
    }

    func testFilterUpstreamFinishesImmediately() {
        var counter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(10),
            createSut: { $0.filter { counter += 1; return $0.isMultiple(of: 2) } }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        XCTAssertEqual(helper.publisher.send(72), .max(10))
        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .value(72)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(counter, 1)
    }

    func testFilterUpstreamFinishesWithError() {
        var counter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(10),
            createSut: { $0.filter { counter += 1; return $0.isMultiple(of: 2) } }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("CustomSubscription"),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("CustomSubscription"),
                        .completion(.failure(.oops)),
                        .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        XCTAssertEqual(helper.publisher.send(74), .max(10))
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history,
                       [.subscription("CustomSubscription"),
                        .completion(.failure(.oops)),
                        .completion(.failure(.oops)),
                        .value(74),
                        .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(counter, 1)
    }

    func testFilterDemand() {
        FilterTests
            .testDemand(subscriberIsAlsoSubscription: false) { publisher, filter in
                publisher.filter { filter($0) != nil }
            }
    }

    func testFilterNoDemand() {
        FilterTests.testNoDemand { $0.filter(shouldNotBeCalled()) }
    }

    func testFilterCancelAlreadyCancelled() throws {
        var counter = 0

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .max(2),
            createSut: { $0.filter { counter += 1; return $0.isMultiple(of: 2) } }
        )

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send(42), .max(2))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled,
                                                     .requested(.unlimited),
                                                     .cancelled])

        helper.publisher.send(completion: .failure(TestingError.oops))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled,
                                                     .requested(.unlimited),
                                                     .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(42),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .completion(.finished)])
        XCTAssertEqual(counter, 1)
    }

    func testFilterReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([.value(0)], demand: .max(42)),
            { $0.filter { _ in true } }
        )
    }

    func testFilterReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.filter { _ in true } }
        )
    }

    func testFilterLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: true,
                          { $0.filter { _ in true } })
    }

    func testFilterReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Filter",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "Filter",
                           subscriberIsAlsoSubscription: false,
                           { $0.filter(shouldNotBeCalled()) })
    }

    // MARK: - TryFilter

    func testTryFilterBasicBehavior() {
        var counter = 0
        FilterTests.testBasicBehavior(
            input: [(1, expectedDemand: .max(1)),
                    (2, expectedDemand: .max(4)),
                    (3, expectedDemand: .max(1)),
                    (4, expectedDemand: .max(4)),
                    (5, expectedDemand: .max(1)),
                    (6, expectedDemand: .max(4)),
                    (7, expectedDemand: .max(1)),
                    (8, expectedDemand: .max(4)),
                    (9, expectedDemand: .max(1))],
            expectedSubscription: "TryFilter",
            expectedOutput: [2, 4, 6, 8],
            { $0.tryFilter { counter += 1; return $0.isMultiple(of: 2) } }
        )
        XCTAssertEqual(counter, 9)
    }

    func testTryFilterCompletesWithErrorWhenThrown() {
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
                                        createSut: { $0.tryFilter(predicate) })

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(42))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
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
                       [.subscription("TryFilter"),
                        .value(2),
                        .value(4),
                        .completion(.failure(TestingError.oops))])

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])
    }

    func testTryFilterUpstreamFinishesImmediately() {
        FilterTests.testUpstreamFinishesImmediately(expectedSubscription: "TryFilter",
                                                    { $0.tryFilter(shouldNotBeCalled()) })
    }

    func testTryFilterUpstreamFinishesWithError() {
        FilterTests.testUpstreamFinishesWithError(expectedSubscription: "TryFilter",
                                                  { $0.tryFilter(shouldNotBeCalled()) })
    }

    func testTryFilterDemand() {
        FilterTests.testDemand { publisher, filter in
            publisher.tryFilter { filter($0) != nil }
        }
    }

    func testTryFilterNoDemand() {
        FilterTests.testNoDemand { $0.tryFilter(shouldNotBeCalled()) }
    }

    func testTryFilterCancelAlreadyCancelled() throws {
        try FilterTests.testCancelAlreadyCancelled(
            expectedSubscription: "TryFilter",
            { $0.tryFilter(shouldNotBeCalled()) }
        )
    }

    func testTryFilterReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .crash,
                                           { $0.tryFilter(shouldNotBeCalled()) })
    }

    func testTryFilterReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .crash,
            { $0.tryFilter(shouldNotBeCalled()) }
        )
    }

    func testTryFilterRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: true,
                                      { $0.tryFilter(shouldNotBeCalled()) })
    }

    func testTryFilterCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.cancelled]),
                                     { $0.tryFilter(shouldNotBeCalled()) })
    }

    func testTryFilterReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.tryFilter(shouldNotBeCalled()) }
    }

    func testTryFilterLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryFilter { _ in true } })
    }

    func testTryFilterReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryFilter",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase"))
                           ),
                           playgroundDescription: "TryFilter",
                           { $0.tryFilter(shouldNotBeCalled()) })
    }

    // MARK: - Operator specializations

    func testFilterOperatorSpecializationForFilter() {
        var counter = 0
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(10),
                                        receiveValueDemand: .max(16)) {
            $0.filter {
                counter += 1
                return $0.isMultiple(of: 2)
            }.filter {
                counter += 1
                return $0.isMultiple(of: 3)
            }
        }

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(1))
        XCTAssertEqual(helper.publisher.send(5), .max(1))
        XCTAssertEqual(helper.publisher.send(6), .max(16))
        XCTAssertEqual(helper.publisher.send(7), .max(1))
        XCTAssertEqual(helper.publisher.send(8), .max(1))
        XCTAssertEqual(helper.publisher.send(9), .max(1))
        XCTAssertEqual(helper.publisher.send(10), .max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(6)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(10))])
        XCTAssertEqual(counter, 15)
        XCTAssert(helper.sut.isIncluded(12))
        XCTAssertEqual(counter, 17)
    }

    func testTryFilterOperatorSpecializationForFilter() {
        var counter = 0
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(10),
                                        receiveValueDemand: .max(16)) {
            $0.filter {
                counter += 1
                return $0.isMultiple(of: 2)
            }.tryFilter {
                counter += 1
                return $0.isMultiple(of: 3)
            }
        }

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(1))
        XCTAssertEqual(helper.publisher.send(5), .max(1))
        XCTAssertEqual(helper.publisher.send(6), .max(16))
        XCTAssertEqual(helper.publisher.send(7), .max(1))
        XCTAssertEqual(helper.publisher.send(8), .max(1))
        XCTAssertEqual(helper.publisher.send(9), .max(1))
        XCTAssertEqual(helper.publisher.send(10), .max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"), .value(6)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(10))])
        XCTAssertEqual(counter, 15)
        XCTAssert(try helper.sut.isIncluded(12))
        XCTAssertEqual(counter, 17)
    }

    func testFilterOperatorSpecializationForTryFilter() {
        var counter = 0
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(10),
                                        receiveValueDemand: .max(16)) {
            $0.tryFilter {
                counter += 1
                return $0.isMultiple(of: 2)
            }.filter {
                counter += 1
                return $0.isMultiple(of: 3)
            }
        }

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(1))
        XCTAssertEqual(helper.publisher.send(5), .max(1))
        XCTAssertEqual(helper.publisher.send(6), .max(16))
        XCTAssertEqual(helper.publisher.send(7), .max(1))
        XCTAssertEqual(helper.publisher.send(8), .max(1))
        XCTAssertEqual(helper.publisher.send(9), .max(1))
        XCTAssertEqual(helper.publisher.send(10), .max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"), .value(6)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(10))])
        XCTAssertEqual(counter, 15)
        XCTAssert(try helper.sut.isIncluded(12))
        XCTAssertEqual(counter, 17)
    }

    func testTryFilterOperatorSpecializationForTryFilter() {
        var counter = 0
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(10),
                                        receiveValueDemand: .max(16)) {
            $0.tryFilter {
                counter += 1
                return $0.isMultiple(of: 2)
            }.tryFilter {
                counter += 1
                return $0.isMultiple(of: 3)
            }
        }

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(1))
        XCTAssertEqual(helper.publisher.send(5), .max(1))
        XCTAssertEqual(helper.publisher.send(6), .max(16))
        XCTAssertEqual(helper.publisher.send(7), .max(1))
        XCTAssertEqual(helper.publisher.send(8), .max(1))
        XCTAssertEqual(helper.publisher.send(9), .max(1))
        XCTAssertEqual(helper.publisher.send(10), .max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription("TryFilter"), .value(6)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(10))])
        XCTAssertEqual(counter, 15)
        XCTAssert(try helper.sut.isIncluded(12))
        XCTAssertEqual(counter, 17)
    }

    // MARK: - Generic tests

    static func testBasicBehavior<Operator: Publisher, Input>(
        input: [(Input, expectedDemand: Subscribers.Demand)],
        expectedSubscription: StringSubscription,
        expectedOutput: [Operator.Output],
        _ makeOperator: (CustomPublisherBase<Input, TestingError>) -> Operator
    ) where Operator.Output: Equatable {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Input, TestingError>.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(4),
            createSut: makeOperator)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])

        for (value, expectedDemand) in input {
            XCTAssertEqual(helper.publisher.send(value), expectedDemand)
        }

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))

        typealias Event = TrackingSubscriberBase<Operator.Output, Operator.Failure>.Event

        var expectedHistory = [Event.subscription(expectedSubscription)]
        expectedHistory.append(contentsOf: expectedOutput.lazy.map(Event.value))
        expectedHistory.append(.completion(.finished))

        XCTAssertEqual(helper.tracking.history, expectedHistory)
    }

    static func testUpstreamFinishesWithError<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    ) where Operator.Output: Equatable, Operator.Failure == Error {

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Error>.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(10),
            createSut: makeOperator
        )

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history,
                       [.subscription(expectedSubscription),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history,
                       [.subscription(expectedSubscription),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        XCTAssertEqual(helper.publisher.send(73), .none)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.tracking.history,
                       [.subscription(expectedSubscription),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
    }

    static func testUpstreamFinishesImmediately<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    ) where Operator.Output: Equatable, Operator.Failure == Error {

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Error>.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(10),
            createSut: makeOperator
        )

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])

        XCTAssertEqual(helper.publisher.send(73), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
    }

    static func testDemand<Operator: Publisher>(
        subscriberIsAlsoSubscription: Bool = true,
        _ makeOperator: (CustomPublisherBase<String, Error>,
                        _ filter: @escaping (String) -> Int?) -> Operator
    )
        where Operator.Output: Equatable, Operator.Failure == Error
    {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<String, Error>(subscription: subscription)
        let operatorPublisher = makeOperator(publisher, Int.init)
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

        XCTAssertEqual(publisher.send("a"), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 5

        XCTAssertEqual(publisher.send("1"), .max(3))
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 5 - 1 + 3 = 7

        demandOnReceiveValue = .max(2)
        XCTAssertEqual(publisher.send("2"), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 7 - 1 + 2 = 8

        demandOnReceiveValue = .max(1)
        XCTAssertEqual(publisher.send("3"), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 8 - 1 + 1 = 8

        XCTAssertEqual(publisher.send("b"), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(5))])
        // unsatisfied demand = 8

        downstreamSubscription?.request(.max(15))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5))])
        // unsatisfied demand = 8 + 15 + 5 = 28

        demandOnReceiveValue = .none
        XCTAssertEqual(publisher.send("4"), demandOnReceiveValue)
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5))])
        // unsatisfied demand = 28 - 1 + 0 = 27

        downstreamSubscription?.request(.max(121))
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5)),
                                              .requested(.max(121))])
        // unsatisfied demand = 27 + 121 = 148

        XCTAssertEqual(publisher.send("c"), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5)),
                                              .requested(.max(121))])
        // unsatisfied demand = 148

        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        if subscriberIsAlsoSubscription {
            XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                                  .requested(.max(15)),
                                                  .requested(.max(5)),
                                                  .requested(.max(121)),
                                                  .cancelled])
        } else {
            XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                                  .requested(.max(15)),
                                                  .requested(.max(5)),
                                                  .requested(.max(121)),
                                                  .cancelled,
                                                  .cancelled])
        }

        downstreamSubscription?.request(.max(3))
        if subscriberIsAlsoSubscription {
            XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                                  .requested(.max(15)),
                                                  .requested(.max(5)),
                                                  .requested(.max(121)),
                                                  .cancelled])
        } else {
            XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                                  .requested(.max(15)),
                                                  .requested(.max(5)),
                                                  .requested(.max(121)),
                                                  .cancelled,
                                                  .cancelled,
                                                  .requested(.max(3))])
        }

        demandOnReceiveValue = .max(80)

        if subscriberIsAlsoSubscription {
            XCTAssertEqual(publisher.send("8"), .none)
        } else {
            XCTAssertEqual(publisher.send("8"), .max(80))
        }
    }

    static func testNoDemand<Operator: Publisher>(
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    )
        where Operator.Output: Equatable, Operator.Failure == Error
    {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Error>(subscription: subscription)
        let operatorPublisher = makeOperator(publisher)
        let tracking = TrackingSubscriberBase<Operator.Output, Error>()
        operatorPublisher.subscribe(tracking)
        XCTAssertTrue(subscription.history.isEmpty)
    }

    static func testCancelAlreadyCancelled<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    ) throws
        where Operator.Output: Equatable, Operator.Failure == Error
    {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Error>.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: makeOperator
        )

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send(42), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        helper.publisher.send(completion: .failure(TestingError.oops))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
    }
}
