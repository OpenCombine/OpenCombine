//
//  CompactMapTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.07.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CompactMapTests: XCTestCase {

    // MARK: - CompactMap

    func testCompactMapBasicBehavior() {
        var counter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<String, TestingError>.self,
            initialDemand: .max(2),
            receiveValueDemand: .max(4),
            createSut: {
                $0.compactMap { string -> Int? in
                    counter += 1
                    return Int(string)
                }
            }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])

        XCTAssertEqual(helper.publisher.send("1"), .max(4))
        XCTAssertEqual(helper.publisher.send("2"), .max(4))
        XCTAssertEqual(helper.publisher.send("a"), .max(1))
        XCTAssertEqual(helper.publisher.send("6"), .max(4))
        XCTAssertEqual(helper.publisher.send("b"), .max(1))
        XCTAssertEqual(helper.publisher.send("b"), .max(1))
        XCTAssertEqual(helper.publisher.send("12.4"), .max(1))

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send("42"), .max(4))

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(6),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .value(42)])
        XCTAssertEqual(counter, 8)
    }

    func testCompactMapUpstreamFinishesImmediately() {
        var counter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<String, TestingError>.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(10),
            createSut: {
                $0.compactMap { input -> Int? in
                    counter += 1
                    return Int(input)
                }
            }
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

        XCTAssertEqual(helper.publisher.send("72"), .max(10))
        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .value(72)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(counter, 1)
    }

    func testCompactMapUpstreamFinishesWithError() {
        var counter = 0
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<String, TestingError>.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(10),
            createSut: {
                $0.compactMap { input -> Int? in
                    counter += 1
                    return Int(input)
                }
            }
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

        XCTAssertEqual(helper.publisher.send("74"), .max(10))
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

    func testCompactMapDemand() {
        FilterTests
            .testDemand(subscriberIsAlsoSubscription: false) { publisher, filter in
                publisher.compactMap(filter)
            }
    }

    func testCompactMapNoDemand() {
        FilterTests.testNoDemand { $0.compactMap(shouldNotBeCalled()) }
    }

    func testCompactMapCancelAlreadyCancelled() throws {
        var counter = 0

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<String, TestingError>.self,
            initialDemand: .unlimited,
            receiveValueDemand: .max(2),
            createSut: {
                $0.compactMap { input -> Int? in
                    counter += 1
                    return Int(input)
                }
            }
        )

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send("42"), .max(2))
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

    func testCompactMapReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: "31",
            expected: .history([.value(31)], demand: .max(42)),
            { $0.compactMap(Int.init) }
        )
    }

    func testCompactMapReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: String.self,
            expected: .history([.completion(.finished)]),
            { $0.compactMap(Int.init) }
        )
    }

    func testCompactMapLifecycle() throws {
        try testLifecycle(sendValue: "31",
                          cancellingSubscriptionReleasesSubscriber: true) {
            $0.compactMap(Int.init)
        }
    }

    func testCompactMapReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "CompactMap",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "CompactMap",
                           subscriberIsAlsoSubscription: false,
                           { $0.compactMap(shouldNotBeCalled()) })
    }

    // MARK: - TryCompactMap

    func testTryCompactMapBasicBehavior() {
        var counter = 0
        // swiftlint:disable comma
        FilterTests.testBasicBehavior(
            input: [("1",    expectedDemand: .max(4)),
                    ("2",    expectedDemand: .max(4)),
                    ("a",    expectedDemand: .max(1)),
                    ("6",    expectedDemand: .max(4)),
                    ("b",    expectedDemand: .max(1)),
                    ("b",    expectedDemand: .max(1)),
                    ("12.4", expectedDemand: .max(1))],
            expectedSubscription: "TryCompactMap",
            expectedOutput: [1, 2, 6],
            { $0.tryCompactMap { counter += 1; return Int($0) } }
        )
        // swiftlint:enable comma
        XCTAssertEqual(counter, 7)
    }

    func testTryCompactMapUpstreamFinishesImmediately() {
        FilterTests
            .testUpstreamFinishesImmediately(expectedSubscription: "TryCompactMap",
                                             { $0.tryCompactMap(shouldNotBeCalled()) })
    }

    func testTryCompactMapUpstreamFinishesWithError() {
        FilterTests
            .testUpstreamFinishesWithError(expectedSubscription: "TryCompactMap",
                                           { $0.tryCompactMap(shouldNotBeCalled()) })
    }

    func testTryCompactMapFailureBecauseOfThrow() {
        var counter = 0 // How many times the transform is called?

        func transform(_ value: String) throws -> Int? {
            counter += 1
            if value == "throw" {
                throw TestingError.oops
            }
            return Int(value)
        }

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<String, TestingError>.self,
            initialDemand: .max(3),
            receiveValueDemand: .max(10),
            createSut: { $0.tryCompactMap(transform) }
        )

        XCTAssertEqual(helper.publisher.send("2"), .max(10))
        XCTAssertEqual(helper.publisher.send("3"), .max(10))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.publisher.send("throw"), .none)
        XCTAssertEqual(helper.publisher.send("9"), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))

        helper.downstreamSubscription?.request(.max(1000))
        helper.downstreamSubscription?.cancel()

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryCompactMap"),
                        .value(2),
                        .value(3),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3)), .cancelled])
        XCTAssertEqual(counter, 3)
    }

    func testTryCompactMapDemand() {
        FilterTests.testDemand { publisher, filter in
            publisher.tryCompactMap(filter)
        }
    }

    func testTryCompactMapNoDemand() {
        FilterTests.testNoDemand { $0.tryCompactMap(shouldNotBeCalled()) }
    }

    func testTryCompactMapCancelAlreadyCancelled() throws {
        try FilterTests.testCancelAlreadyCancelled(
            expectedSubscription: "TryCompactMap",
            { $0.tryCompactMap(shouldNotBeCalled()) }
        )
    }

    func testTryCompactMapReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .crash,
                                           { $0.tryCompactMap(shouldNotBeCalled()) })
    }

    func testTryCompactMapReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .crash,
            { $0.tryCompactMap(shouldNotBeCalled()) }
        )
    }

    func testTryCompactMapRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: true,
                                      { $0.tryCompactMap(shouldNotBeCalled()) })
    }

    func testTryCompactMapCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.cancelled]),
                                     { $0.tryCompactMap(shouldNotBeCalled()) })
    }

    func testTryCompactMapReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.tryCompactMap(shouldNotBeCalled()) }
    }

    func testTryCompactMapLifecycle() throws {
        try testLifecycle(sendValue: "31",
                          cancellingSubscriptionReleasesSubscriber: false) {
            $0.tryCompactMap(Int.init)
        }
    }

    func testTryCompactMapReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryCompactMap",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase"))
                           ),
                           playgroundDescription: "TryCompactMap",
                           { $0.tryCompactMap(shouldNotBeCalled()) })
    }

    // MARK: - Operator Specializations

    func testCompactMapOperatorSpecializationForCompactMap() {
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )

        let publisher = CustomPublisherBase<String, TestingError>(
            subscription: CustomSubscription()
        )

        let compactMap1 = publisher.compactMap(Int.init)
        let compactMap2 = compactMap1.compactMap { $0.isMultiple(of: 2) ? $0 / 2 : nil }

        compactMap2.subscribe(tracking)
        XCTAssertEqual(publisher.send("0"), .none)
        XCTAssertEqual(publisher.send("3"), .max(1))
        XCTAssertEqual(publisher.send("a"), .max(1))
        XCTAssertEqual(publisher.send("12"), .none)
        XCTAssertEqual(publisher.send("11"), .max(1))
        XCTAssertEqual(publisher.send("20"), .none)
        XCTAssertEqual(publisher.send("b"), .max(1))
        publisher.send(completion: .finished)

        XCTAssert(compactMap1.upstream === compactMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .value(0),
                                          .value(6),
                                          .value(10),
                                          .completion(.finished)])
    }

    func testMapOperatorSpecializationForCompactMap() {
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )

        let publisher = CustomPublisherBase<String, TestingError>(
            subscription: CustomSubscription()
        )

        let compactMap1 = publisher.compactMap(Int.init)
        let compactMap2 = compactMap1.map { $0 + 1 }

        compactMap2.subscribe(tracking)
        XCTAssertEqual(publisher.send("0"), .none)
        XCTAssertEqual(publisher.send("3"), .none)
        XCTAssertEqual(publisher.send("a"), .max(1))
        XCTAssertEqual(publisher.send("12"), .none)
        XCTAssertEqual(publisher.send("11"), .none)
        XCTAssertEqual(publisher.send("20"), .none)
        XCTAssertEqual(publisher.send("b"), .max(1))
        publisher.send(completion: .finished)

        XCTAssert(compactMap1.upstream === compactMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .value(1),
                                          .value(4),
                                          .value(13),
                                          .value(12),
                                          .value(21),
                                          .completion(.finished)])
    }

    func testCompactMapOperatorSpecializationForTryCompactMap() {
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<String, Never>()

        let tryCompactMap1 = publisher.tryCompactMap { input -> Int? in
            if input == "throw" { throw TestingError.oops }
            return Int(input)
        }

        let tryCompactMap2 = tryCompactMap1
            .compactMap { $0.isMultiple(of: 2) ? $0 / 2 : nil }

        tryCompactMap2.subscribe(tracking)
        publisher.send("0")
        publisher.send("3")
        publisher.send("a")
        publisher.send("12")
        publisher.send("11")
        publisher.send("20")
        publisher.send("b")

        XCTAssert(tryCompactMap1.upstream === tryCompactMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("TryCompactMap"),
                                          .value(0),
                                          .value(6),
                                          .value(10)])

        publisher.send("throw")

        XCTAssertEqual(tracking.history, [.subscription("TryCompactMap"),
                                          .value(0),
                                          .value(6),
                                          .value(10),
                                          .completion(.failure(TestingError.oops))])
    }
}
