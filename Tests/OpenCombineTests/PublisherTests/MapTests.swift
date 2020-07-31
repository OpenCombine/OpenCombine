//
//  MapTests.swift
//
//
//  Created by Anton Nazarov on 25/06/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MapTests: XCTestCase {

    func testEmpty() {
        MapTests.testEmpty(valueComparator: ==) {
            $0.map(String.init)
        }
    }

    func testTryMapEmpty() {
        // Given
        let tracking = TrackingSubscriberBase<String, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubjectBase<Int, Error>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "TryMap")
            }
        )
        // When
        publisher.tryMap(String.init).subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("TryMap")])
    }

    func testError() {
        MapTests.testError(valueComparator: ==) { $0.map { $0 * 2 } }
    }

    func testTryMapFailureBecauseOfThrow() {
        var counter = 0 // How many times the transform is called?

        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Error>(subscription: subscription)
        let map = publisher.tryMap { value -> Int in
            counter += 1
            if value == 100 {
                throw TestingError.oops
            }
            return value * 2
        }
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        XCTAssertEqual(publisher.send(1), .none)
        map.subscribe(tracking)
        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(publisher.send(3), .none)
        XCTAssertEqual(publisher.send(100), .none)
        XCTAssertEqual(publisher.send(9), .none)
        XCTAssertEqual(publisher.send(100), .none)
        publisher.send(completion: .finished)
        XCTAssertEqual(publisher.send(100), .none)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryMap"),
                        .value(4),
                        .value(6),
                        .completion(.failure(TestingError.oops)),
                        .value(18),
                        .completion(.failure(TestingError.oops)),
                        .completion(.failure(TestingError.oops))])

        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(counter, 6)
    }

    func testTryMapFailureOnCompletion() {

        let publisher = PassthroughSubject<Int, Error>()
        let map = publisher.tryMap { $0 * 2 }

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        map.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        publisher.send(2)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryMap"),
                        .completion(.failure(TestingError.oops))])
    }

    func testTryMapSuccess() {
        let publisher = PassthroughSubject<Int, Error>()
        let map = publisher.tryMap { $0 * 2 }

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        map.subscribe(tracking)
        publisher.send(completion: .finished)
        publisher.send(2)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryMap"),
                        .completion(.finished)])
    }

    func testRange() {
        let mapping: (Int) -> Int = { $0 * 2 }
        MapTests.testRange(valueComparator: ==, mapping: mapping) {
            $0.map(mapping)
        }
    }

    func testNoDemand() {
        MapTests.testNoDemand { $0.map { $0 * 2 } }
    }

    func testRequestDemandOnSubscribe() {
        MapTests.testRequestDemandOnSubscribe { $0.map { $0 * 2 } }
    }

    func testDemandOnReceive() {
        MapTests.testDemandOnReceive { $0.map { $0 * 2 } }
    }

    func testCompletion() {
        MapTests.testCompletion(valueComparator: ==) { $0.map { $0 * 2 } }
    }

    func testMapCancel() throws {
        try MapTests.testCancel { $0.map { $0 * 2 } }
    }

    func testTryMapCancel() throws {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.tryMap { $0 * 2 }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Error>(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })

        map.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send(1), .none)
        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(tracking.history, [.subscription("TryMap"), .value(2)])
    }

    func testMapCancelAlreadyCancelled() throws {
        try MapTests.testCancelAlreadyCancelled { $0.map { $0 * 2 } }
    }

    func testTryMapCancelAlreadyCancelled() throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = publisher.tryMap { $0 * 2 }
        let tracking = TrackingSubscriberBase<Int, Error>()
        map.subscribe(tracking)

        let downstreamSubscription =
            try XCTUnwrap(tracking.subscriptions.first?.underlying)

        downstreamSubscription.cancel()
        downstreamSubscription.request(.unlimited)
        downstreamSubscription.cancel()

        XCTAssertEqual(subscription.history, [.cancelled])
    }

    func testTryMapReceiveSubscriptionTwice() throws {

        let firstSubscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: firstSubscription)
        let map = publisher.tryMap { _ -> Int in throw TestingError.oops }
        let tracking = TrackingSubscriberBase<Int, Error>()
        map.subscribe(tracking)

        XCTAssertEqual(firstSubscription.history, [])
        XCTAssertEqual(tracking.history, [.subscription("TryMap")])

        let secondSubscription = CustomSubscription()
        try XCTUnwrap(publisher.subscriber).receive(subscription: secondSubscription)

        XCTAssertEqual(firstSubscription.history, [])
        XCTAssertEqual(secondSubscription.history, [.cancelled])
        XCTAssertEqual(tracking.history, [.subscription("TryMap")])

        XCTAssertEqual(publisher.send(0), .none) // Throws an error

        XCTAssertEqual(firstSubscription.history, [.cancelled])
        XCTAssertEqual(secondSubscription.history, [.cancelled])
        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .completion(.failure(TestingError.oops))])
        try XCTUnwrap(publisher.subscriber).receive(subscription: secondSubscription)

        XCTAssertEqual(firstSubscription.history, [.cancelled])
        XCTAssertEqual(secondSubscription.history, [.cancelled, .cancelled])
        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .completion(.failure(TestingError.oops))])
    }

    func testMapReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "Map",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "Map",
                           subscriberIsAlsoSubscription: false,
                           { $0.map { $0 * 2 } })
    }

    func testTryMapReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "TryMap",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "TryMap",
                           { $0.tryMap { $0 * 2 } })
    }

    func testMapReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(0)],
                                                              demand: .max(42)),
                                           { $0.map { $0 } })
        // swiftlint:disable:previous array_init
    }

    func testMapReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.map(shouldNotBeCalled()) }
        )
    }

    func testMapLifecycle() throws {
        try testLifecycle(sendValue: 31, cancellingSubscriptionReleasesSubscriber: true) {
            $0.map { $0 * 2 }
        }
    }

    func testTryMapReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(0)],
                                                              demand: .max(42)),
                                           { $0.tryMap { $0 } })
    }

    func testTryMapReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryMap(shouldNotBeCalled()) }
        )
    }

    func testTryMapRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryMap(shouldNotBeCalled()) })
    }

    func testTryMapCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     shouldCrash: false,
                                     { $0.tryMap(shouldNotBeCalled()) })
    }

    func testTryMapLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false) {
            $0.tryMap { $0 * 2 }
        }
    }

    func testMapOperatorSpecializationForMap() {

        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let map1 = publisher.map { $0 * 2 }
        let map2 = map1.map { $0 + 1 }

        map2.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(5)
        publisher.send(completion: .finished)

        XCTAssert(map1.upstream === map2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject"),
                                          .value(5),
                                          .value(7),
                                          .value(11),
                                          .completion(.finished)])
    }

    func testTryMapOperatorSpecializationForMap() {
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let map1 = publisher.map { $0 * 2 }

        let tryMap2 = map1.tryMap { input -> Int in
            if input == 12 { throw TestingError.oops }
            return input + 1
        }

        tryMap2.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(5)

        XCTAssert(map1.upstream === tryMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11)])

        publisher.send(6)

        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11),
                                          .completion(.failure(TestingError.oops))])
    }

    func testMapOperatorSpecializationForTryMap() {
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let tryMap1 = publisher.tryMap { input -> Int in
            if input == 6 { throw TestingError.oops }
            return input * 2
        }

        let tryMap2 = tryMap1.map { $0 + 1 }

        tryMap2.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(5)

        XCTAssert(tryMap1.upstream === tryMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11)])

        publisher.send(6)

        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11),
                                          .completion(.failure(TestingError.oops))])
    }

    func testTryMapOperatorSpecializationForTryMap() {
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<Int, Never>()

        let tryMap1 = publisher.tryMap { input -> Int in
            if input == 6 { throw TestingError.oops }
            return input * 2
        }

        let tryMap2 = tryMap1.tryMap { $0 + 1 }

        tryMap2.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(5)

        XCTAssert(tryMap1.upstream === tryMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11)])

        publisher.send(6)

        XCTAssertEqual(tracking.history, [.subscription("TryMap"),
                                          .value(5),
                                          .value(7),
                                          .value(11),
                                          .completion(.failure(TestingError.oops))])
    }

    // MARK: - Generic tests (for supporting Publishers.MapKeyPath)

    static func testEmpty<Map: Publisher>(
        valueComparator: (Map.Output, Map.Output) -> Bool,
        _ map: (TrackingSubject<Int>) -> Map
    ) where Map.Failure == TestingError {
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubject<Int>()

        map(publisher).subscribe(tracking)

        tracking.assertHistoryEqual([.subscription("PassthroughSubject")],
                                    valueComparator: valueComparator)
    }

    static func testError<Map: Publisher>(
        valueComparator: (Map.Output, Map.Output) -> Bool,
        _ map: (CustomPublisher) -> Map
    ) where Map.Failure == TestingError {
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = CustomPublisher(subscription: CustomSubscription())

        map(publisher).subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        publisher.send(completion: .failure(expectedError))

        tracking.assertHistoryEqual([.subscription("CustomSubscription"),
                                     .completion(.failure(expectedError)),
                                     .completion(.failure(expectedError))],
                                    valueComparator: valueComparator)
    }

    static func testRange<Map: Publisher>(
        valueComparator: (Map.Output, Map.Output) -> Bool,
        mapping: (Int) -> Map.Output,
        _ map: (PassthroughSubject<Int, TestingError>) -> Map
    ) where Map.Failure == TestingError {
        let publisher = PassthroughSubject<Int, TestingError>()
        let map = map(publisher)
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.send(1)
        map.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(completion: .finished)
        publisher.send(5)

        tracking.assertHistoryEqual([.subscription("PassthroughSubject"),
                                     .value(mapping(2)),
                                     .value(mapping(3)),
                                     .completion(.finished)],
                                    valueComparator: valueComparator)
    }

    static func testNoDemand<Map: Publisher>(
        _ map: (CustomPublisher) -> Map
    ) where Map.Failure == TestingError {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = map(publisher)
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>()

        map.subscribe(tracking)

        XCTAssertTrue(subscription.history.isEmpty)
    }

    static func testRequestDemandOnSubscribe<Map: Publisher>(
        _ map: (CustomPublisher) -> Map
    ) where Map.Failure == TestingError {
        let expectedSubscribeDemand = 42
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = map(publisher)
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>(
            receiveSubscription: { $0.request(.max(expectedSubscribeDemand)) }
        )

        map.subscribe(tracking)

        XCTAssertEqual(subscription.history,
                       [.requested(.max(expectedSubscribeDemand))])
    }

    static func testDemandOnReceive<Map: Publisher>(
        _ map: (CustomPublisher) -> Map
    ) where Map.Failure == TestingError {
        var expectedReceiveValueDemand = 4
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = map(publisher)
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in .max(expectedReceiveValueDemand) }
        )

        map.subscribe(tracking)

        XCTAssertEqual(publisher.send(0), .max(4))

        expectedReceiveValueDemand = 120

        XCTAssertEqual(publisher.send(0), .max(120))

        XCTAssertEqual(subscription.history,
                       [.requested(.unlimited)])
    }

    static func testCompletion<Map: Publisher>(
        valueComparator: (Map.Output, Map.Output) -> Bool,
        _ map: (CustomPublisher) -> Map
    ) where Map.Failure == TestingError {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = map(publisher)
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        map.subscribe(tracking)
        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history,
                       [.requested(.unlimited)])

        tracking.assertHistoryEqual([.subscription("CustomSubscription"),
                                     .completion(.finished)],
                                    valueComparator: valueComparator)
    }

    static func testCancel<Map: Publisher>(
        _ map: (CustomPublisher) -> Map
    ) throws where Map.Failure == TestingError {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = map(publisher)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>(
            receiveSubscription: {
                $0.request(.unlimited)
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(111) }
        )

        map.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send(1), .max(111))

        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history,
                       [.requested(.unlimited), .cancelled])
    }

    static func testCancelAlreadyCancelled<Map: Publisher>(
        file: StaticString = #file,
        line: UInt = #line,
        _ map: (CustomPublisher) -> Map
    ) throws where Map.Failure == TestingError {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let map = map(publisher)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Map.Output, TestingError>(
            receiveSubscription: {
                $0.request(.unlimited)
                downstreamSubscription = $0
            }
        )

        map.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(downstreamSubscription).cancel()

        XCTAssertEqual(subscription.history,
                       [.requested(.unlimited),
                        .cancelled,
                        .requested(.unlimited),
                        .cancelled])
    }
}
