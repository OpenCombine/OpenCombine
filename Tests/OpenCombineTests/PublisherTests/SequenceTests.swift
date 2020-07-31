//
//  SequenceTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.07.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class SequenceTests: XCTestCase {

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)
    private typealias ResultPublisher<Output, Failure: Error> =
        Result<Output, Failure>.Publisher
#else
    private typealias ResultPublisher<Output, Failure: Error> =
        Result<Output, Failure>.OCombine.Publisher
#endif

    func testEmptySequence() {

        let emptyCounter = Counter(upperBound: 0)
        let publisher = makePublisher(emptyCounter)
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { subscription in
                XCTAssertEqual(String(describing: subscription), "Empty")
            }
        )

        XCTAssertEqual(emptyCounter.state, 0)

        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])
        XCTAssertEqual(emptyCounter.state, 1)
    }

    func testSequenceNoInitialDemand() throws {

        let counter = Counter(upperBound: 10)
        let publisher = makePublisher(counter)
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                XCTAssertEqual(String(describing: $0), "Counter")
                var reflected = ""
                dump($0, to: &reflected)
                XCTAssertEqual(reflected, """
                ▿ Counter #0
                  ▿ sequence: Counter #1
                    - upperBound: 10
                    - state: 1

                """)
            }
        )

        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Counter")])

        subscriber.subscriptions.first?.request(.max(3))

        XCTAssertEqual(subscriber.history, [.subscription("Counter"),
                                            .value(0),
                                            .value(1),
                                            .value(2)])

        subscriber.subscriptions.first?.request(.max(5))

        XCTAssertEqual(subscriber.history, [.subscription("Counter"),
                                            .value(0),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7)])

        subscriber.subscriptions.first?.request(.none)

        XCTAssertEqual(subscriber.history, [.subscription("Counter"),
                                            .value(0),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7)])

        subscriber.subscriptions.first?.request(.max(2))

        XCTAssertEqual(subscriber.history, [.subscription("Sequence"),
                                            .value(0),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7),
                                            .value(8),
                                            .value(9),
                                            .completion(.finished)])

        var reflected = ""
        try dump(XCTUnwrap(subscriber.subscriptions.first), to: &reflected)
        XCTAssertEqual(reflected, """
        ▿ Sequence
          ▿ subscription: Sequence #0
            - sequence: 0 elements

        """)
    }

    func testSequenceInitialDemand() {
        let counter = Counter(upperBound: 10)
        let publisher = makePublisher(counter)
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: {
                $0 > 3 || $0 == 0 ? .none : .max(2)
            }
        )

        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Counter"),
                                            .value(0)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription("Counter"),
                                            .value(0),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7)])
    }

    func testCancelOnSubscription() {
        let counter = Counter(upperBound: 3)
        let publisher = makePublisher(counter)
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)); $0.cancel() }
        )
        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Sequence"),
                                            .value(0)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription("Sequence"),
                                            .value(0)])
    }

    func testCancelOnValue() {
        let counter = Counter(upperBound: 3)
        let publisher = makePublisher(counter)
        var subscription: Subscription?
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                subscription = $0
                $0.request(.unlimited)
            },
            receiveValue: { _ in
                subscription?.cancel()
                return .unlimited
            }
        )
        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Sequence"),
                                            .value(0)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription("Sequence"),
                                            .value(0)])
    }

    func testPublishesCorrectValues() {
        let sequence = makePublisher(1...5)

        var history = [Int]()
        _ = sequence.sink {
            history.append($0)
        }

        XCTAssertEqual(history, [1, 2, 3, 4, 5])
    }

    func testRecursion() {
        let sequence = makePublisher(1...5)

        var history = [Int]()
        var storedSubscription: Subscription?

        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { subscription in
                storedSubscription = subscription
                subscription.request(.none) // Shouldn't crash
                subscription.request(.max(1))
            },
            receiveValue: { value in
                storedSubscription?.request(.max(1))
                history.append(value)
                return .none
            }
        )

        sequence.subscribe(tracking)

        XCTAssertEqual(history, [1, 2, 3, 4, 5])
    }

    func testReflection() throws {

        try testSubscriptionReflection(description: "1...5",
                                       customMirror:
                                           expectedChildren(("sequence", "1...5")),
                                       playgroundDescription: "1...5",
                                       sut: makePublisher(1...5))
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = {
            deinitCounter += 1
        }

        do {
            let counter = Counter(upperBound: 3)
            let publisher = makePublisher(counter)
            let subscriber = TrackingSubscriberBase<Int, Never>(onDeinit: onDeinit)
            XCTAssertTrue(subscriber.history.isEmpty)

            publisher.subscribe(subscriber)
            XCTAssertEqual(subscriber.history, [.subscription("Counter")])

            subscriber.subscriptions.first?.request(.max(3))
            XCTAssertEqual(subscriber.history, [.subscription("Sequence"),
                                                .value(0),
                                                .value(1),
                                                .value(2),
                                                .completion(.finished)])
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let counter = Counter(upperBound: 1)
            let publisher = makePublisher(counter)
            let subscriber = TrackingSubscriberBase<Int, Never>(
                receiveSubscription: { subscription = $0 },
                onDeinit: onDeinit
            )
            XCTAssertTrue(subscriber.history.isEmpty)
            publisher.subscribe(subscriber)
            XCTAssertEqual(subscriber.history, [.subscription("Counter")])
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 1)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 2)
    }

    // MARK: - Operator specializations for Sequence

    func testAllSatisfyOperatorSpecialization() {
        XCTAssertEqual(makePublisher([1, 1, -2, 3]).allSatisfy { $0 > 0 }, .init(false))
        XCTAssertEqual(makePublisher(1 ..< 10).allSatisfy { $0 > 0 }, .init(true))
    }

    func testTryAllSatisfyOperatorSpecialization() {
        XCTAssertFalse(
            try makePublisher([1, 1, -2, 3]).tryAllSatisfy { $0 > 0 }.result.get()
        )
        XCTAssertTrue(try makePublisher(1 ..< 10).tryAllSatisfy { $0 > 0 }.result.get())
        XCTAssertTrue(try makePublisher([]).tryAllSatisfy(throwing).result.get())
        assertThrowsError(
            try makePublisher(1 ..< 10).tryAllSatisfy(throwing).result.get(),
            .oops
        )
    }

    func testCollectOperatorSpecialization() {
        XCTAssertEqual(makePublisher(1 ..< 5).collect(), .init([1, 2, 3, 4]))
        XCTAssertEqual(makePublisher(EmptyCollection<Int>()).collect(), .init([]))
    }

    func testCompactMapOperatorSpecialization() {
        let transform: (Int) -> String? = { $0 == 42 ? nil : String($0) }
        XCTAssertEqual(makePublisher(40 ..< 45).compactMap(transform),
                       .init(sequence: ["40", "41", "43", "44"]))
    }

    func testMinOperatorSpecialization() {
        XCTAssertEqual(makePublisher(EmptyCollection<Int>()).min(), .init(nil))
        XCTAssertEqual(makePublisher([3, 4, 5, -1, 2]).min(), .init(-1))
        XCTAssertEqual(makePublisher([3, 4, 5, -1, 2]).min(by: >), .init(5))
    }

    func testMaxOperatorSpecialization() {
        XCTAssertEqual(makePublisher(EmptyCollection<Int>()).max(), .init(nil))
        XCTAssertEqual(makePublisher([3, 4, 5, -1, 2]).max(), .init(5))
        XCTAssertEqual(makePublisher([3, 4, 5, -1, 2]).max(by: >), .init(-1))
    }

    func testContainsOperatorSpecialization() {
        XCTAssertEqual(makePublisher(EmptyCollection<Int>()).contains(12), .init(false))
        XCTAssertEqual(makePublisher(0 ..< 12).contains(12), .init(false))
        XCTAssertEqual(makePublisher(0 ... 12).contains(12), .init(true))

        XCTAssertEqual(makePublisher(99 ..< 200).contains { $0 < 100 }, .init(true))
        XCTAssertEqual(makePublisher(90 ..< 100).contains { $0 > 100 }, .init(false))
    }

    func testTryContainsOperatorSpecialization() {
        XCTAssertFalse(try makePublisher(0 ..< 100).tryContains { $0 > 100 }.result.get())
        XCTAssertTrue(try makePublisher(99 ..< 200).tryContains { $0 < 100 }.result.get())
        XCTAssertFalse(
            try makePublisher(EmptyCollection<Int>())
                .tryContains(where: throwing).result.get()
        )
        assertThrowsError(
            try makePublisher([2]).tryContains(where: throwing).result.get(),
            .oops
        )
    }

    func testDropWhileOperatorSpecialization() {
        XCTAssertEqual(Array(makePublisher(0 ..< 7).drop { $0 < 5 }.sequence), [5, 6])
        XCTAssertEqual(
            Array(makePublisher(EmptyCollection<Int>()).drop { _ in true }.sequence),
            []
        )
    }

    func testDropFirstOperatorSpecialization() {
        XCTAssertEqual(Array(makePublisher(0 ..< 4).dropFirst().sequence), [1, 2, 3])
        XCTAssertEqual(Array(makePublisher(0 ..< 4).dropFirst(3).sequence), [3])
        XCTAssertEqual(
            Array(makePublisher(EmptyCollection<Int>()).dropFirst(.max).sequence),
            []
        )
    }

    func testFirstWhereOperatorSpecialization() {
        XCTAssertEqual(makePublisher(1 ..< 9).first { $0.isMultiple(of: 4) }, .init(4))
        XCTAssertEqual(makePublisher(1 ..< 9).first { $0.isMultiple(of: 13) }, .init(nil))
        XCTAssertEqual(
            makePublisher(EmptyCollection<Int>()).first { $0.isMultiple(of: 13) },
            .init(nil)
        )
    }

    func testFilterOperatorSpecialization() {
        XCTAssertEqual(makePublisher(0 ..< 10).filter { $0.isMultiple(of: 3) },
                       .init(sequence: [0, 3, 6, 9]))
    }

    func testIgnoreOutputOperatorSpecialization() {
        XCTAssertTrue(makePublisher(0 ..< 10).ignoreOutput().completeImmediately)
    }

    func testMapOperatorSpecialization() {
        XCTAssertEqual(makePublisher(0 ..< 5).map { $0 * 2 },
                       .init(sequence: [0, 2, 4, 6, 8]))
    }

    func testPrefixOperatorSpecialization() {
        XCTAssertEqual(Array(makePublisher(0 ..< 10).prefix(0).sequence), [])
        XCTAssertEqual(Array(makePublisher(0 ..< 10).prefix(3).sequence), [0, 1, 2])
        XCTAssertEqual(Array(makePublisher(0 ..< 3).prefix(10).sequence), [0, 1, 2])
    }

    func testPrefixWhileOperatorSpecialization() {
        XCTAssertEqual(Array(makePublisher(0 ..< 10).prefix { $0 < 4 }.sequence),
                       [0, 1, 2, 3])
        XCTAssertEqual(Array(makePublisher(0 ..< 10).prefix { $0 < 0 }.sequence),
                       [])
        XCTAssertEqual(
            Array(makePublisher(EmptyCollection<Int>()).prefix { $0 < 0 }.sequence),
            []
        )
    }

    func testReduceOperatorSpecialization() {
        XCTAssertEqual(makePublisher(0 ..< 5).reduce(10, +), .init(20))
        XCTAssertEqual(makePublisher(EmptyCollection<Int>()).reduce(1, *), .init(1))
    }

    func testTryReduceOperatorSpecialization() {
        XCTAssertEqual(try makePublisher(0 ..< 5).tryReduce(10, +).result.get(), 20)
        XCTAssertEqual(
            try makePublisher(EmptyCollection<Int>()).tryReduce(1, *).result.get(),
            1
        )
        XCTAssertEqual(
            try makePublisher(EmptyCollection<Int>()).tryReduce(1, throwing).result.get(),
            1
        )

        assertThrowsError(try makePublisher([1]).tryReduce(2, throwing).result.get(),
                          .oops)
    }

    func testReplaceNilOperatorSpecialization() {
        XCTAssertEqual(makePublisher([1, 2, nil, 4, 5, nil]).replaceNil(with: 42),
                       .init(sequence: [1, 2, 42, 4, 5, 42]))

        XCTAssertEqual(makePublisher(EmptyCollection<Int?>()).replaceNil(with: 42),
                       .init(sequence: []))
    }

    func testScanOperatorSpecialization() {
        XCTAssertEqual(makePublisher(0 ..< 5).scan(0, +),
                       .init(sequence: [0, 1, 3, 6, 10]))
        XCTAssertEqual(makePublisher(0 ..< 5).scan(1, -),
                       .init(sequence: [1, 0, -2, -5, -9]))
    }

    func testSetFailureTypeOperatorSpecialization() {
        XCTAssertEqual(
            makePublisher(CollectionOfOne(42))
                .setFailureType(to: TestingError.self).sequence.first,
            42
        )
    }

    func testRemoveDuplicatesOperatorSpecialization() {
        XCTAssertEqual(
            makePublisher([0, 0, 1, 0, 1, 1, 2, 2, 3, 3, 3, 3, 3, 1]).removeDuplicates(),
            .init(sequence: [0, 1, 0, 1, 2, 3, 1])
        )
    }

    func testFirstOperatorSpecialization() {
        XCTAssertEqual(makePublisher([1, 2, 3]).first(), .init(1))
        XCTAssertEqual(makePublisher(EmptyCollection<Int>()).first(), .init(nil))
    }

    func testCountOperatorSpecialization() {
        XCTAssertEqual(makePublisher(0 ..< .max).count(), Just(.max))
        XCTAssertEqual(makePublisher(EmptyCollection<Int>()).count(), Just(0))
        XCTAssertEqual(makePublisher([1, 1, 1, 1, 1, 1]).count(), Just(6))
        XCTAssertEqual(
            makePublisher([1, 1, 1, 1, 1, 1])
                .setFailureType(to: TestingError.self)
                .count(),
            ResultPublisher(.success(6))
        )
        XCTAssertEqual(
            makePublisher([1, 2, 3, 4, 5, 6].lazy.filter { $0.isMultiple(of: 2) })
                .count(),
            ResultPublisher(.success(3))
        )
        XCTAssertEqual(makePublisher([]).count(), Just(0))
    }

    func testOutputAtIndexOperatorSpecialization() {
        let tracking = TrackingCollection<Int>([1, 2, 3, 4, 5, 6, 7])

        XCTAssertEqual(tracking.history, [.initFromSequence])

        XCTAssertEqual(makePublisher(tracking).output(at: 3), .init(4))

        XCTAssertEqual(tracking.history, [.initFromSequence,
                                          .indices,
                                          .subscriptPosition])

        XCTAssertEqual(makePublisher(tracking).output(at: 100), .init(nil))
        XCTAssertEqual(tracking.history, [.initFromSequence,
                                          .indices,
                                          .subscriptPosition,
                                          .indices])

        XCTAssertEqual(makePublisher(tracking).output(at: -1), .init(nil))
        XCTAssertEqual(tracking.history, [.initFromSequence,
                                          .indices,
                                          .subscriptPosition,
                                          .indices,
                                          .indices])

        XCTAssertEqual(makePublisher([1, 2, 3, 4, 5, 6, 7]).output(at: 3), .init(4))
        XCTAssertEqual(makePublisher([1, 2, 3, 4, 5, 6, 7]).output(at: 100), .init(nil))
        XCTAssertEqual(makePublisher([1, 2, 3, 4, 5, 6, 7]).output(at: -1), .init(nil))
    }

    func testOutputInRangeOperatorSpecialization() {
        let tracking = TrackingCollection<Int>([1, 2, 3, 4, 5, 6, 7])

        XCTAssertEqual(tracking.history, [.initFromSequence])

        XCTAssertEqual(makePublisher(tracking).output(in: 1 ..< 4),
                       .init(sequence: [2, 3, 4]))

        XCTAssertEqual(tracking.history, [.initFromSequence,
                                          .subscriptBounds,
                                          .distance,
                                          .subscriptPosition,
                                          .formIndexAfter,
                                          .subscriptPosition,
                                          .formIndexAfter,
                                          .subscriptPosition,
                                          .formIndexAfter])

        XCTAssertEqual(makePublisher([1, 2, 3, 4, 5, 6, 7]).output(in: 1 ..< 4),
                       .init(sequence: [2, 3, 4]))
    }

    func testLastOperatorSpecialization() {
        XCTAssertEqual(makePublisher([1, 2, 3]).last(), .init(3))
        XCTAssertEqual(makePublisher(EmptyCollection<Int>()).last(), .init(nil))
    }

    func testLastWhereOperatorSpecialization() {
        XCTAssertEqual(makePublisher(1 ..< 9).last { $0.isMultiple(of: 4) }, .init(8))
        XCTAssertEqual(makePublisher(1 ..< 9).last { $0.isMultiple(of: 13) }, .init(nil))
        XCTAssertEqual(
            makePublisher(EmptyCollection<Int>()).last { $0.isMultiple(of: 13) },
            .init(nil)
        )
    }

    func testPrependVariadicOperatorSpecialization() {
        let baseCollection = TrackingCollection<Int>([4, 5, 6, 7])

        XCTAssertEqual(baseCollection.history, [.initFromSequence])

        let newCollection = makePublisher(baseCollection).prepend(1, 2, 3).sequence
        XCTAssertEqual(baseCollection.storage, [4, 5, 6, 7])
        XCTAssertEqual(newCollection.storage, [1, 2, 3, 4, 5, 6, 7])

        XCTAssertEqual(baseCollection.history, [.initFromSequence,
                                                .count,
                                                .underestimatedCount,
                                                .makeIterator])

        XCTAssertEqual(newCollection.history, [.emptyInit,
                                               .reserveCapacity,
                                               .appendSequence,
                                               .appendSequence])
    }

    func testPrependSequenceOperatorSpecialization() {

        let baseCollection = TrackingCollection<Int>([4, 5, 6, 7])
        let prependee = TrackingCollection<Int>([1, 2, 3])

        XCTAssertEqual(baseCollection.history, [.initFromSequence])
        XCTAssertEqual(prependee.history, [.initFromSequence])

        let newCollection = makePublisher(baseCollection).prepend(prependee).sequence
        XCTAssertEqual(newCollection.storage, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(baseCollection.storage, [4, 5, 6, 7])
        XCTAssertEqual(prependee.storage, [1, 2, 3])

        XCTAssertEqual(baseCollection.history, [.initFromSequence,
                                                .count,
                                                .underestimatedCount,
                                                .makeIterator])

        XCTAssertEqual(prependee.history, [.initFromSequence,
                                          .underestimatedCount,
                                          .underestimatedCount,
                                          .makeIterator])

        XCTAssertEqual(newCollection.history, [.emptyInit,
                                               .reserveCapacity,
                                               .appendSequence,
                                               .appendSequence])
    }

    func testPrependPublisherOperatorSpecialization() {
        let baseCollection = TrackingCollection<Int>([4, 5, 6, 7])
        let prependee = TrackingCollection<Int>([1, 2, 3])

        XCTAssertEqual(baseCollection.history, [.initFromSequence])
        XCTAssertEqual(prependee.history, [.initFromSequence])

        let newCollection = makePublisher(baseCollection)
            .prepend(makePublisher(prependee))
            .sequence
        XCTAssertEqual(newCollection.storage, [1, 2, 3, 4, 5, 6, 7] )
        XCTAssertEqual(baseCollection.storage, [4, 5, 6, 7])
        XCTAssertEqual(prependee.storage, [1, 2, 3, 4, 5, 6, 7])

        XCTAssertEqual(baseCollection.history, [.initFromSequence,
                                                .underestimatedCount,
                                                .makeIterator])

        XCTAssertEqual(prependee.history, [.initFromSequence,
                                          .appendSequence])

        XCTAssertEqual(newCollection.history, [.initFromSequence, .appendSequence])
    }

    func testAppendVariadicOperatorSpecialization() {
        let baseCollection = TrackingCollection<Int>([1, 2, 3])

        XCTAssertEqual(baseCollection.history, [.initFromSequence])

        let newCollection = makePublisher(baseCollection).append(4, 5, 6, 7).sequence
        XCTAssertEqual(baseCollection.storage, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(newCollection.storage, [1, 2, 3, 4, 5, 6, 7])

        XCTAssertEqual(baseCollection.history, [.initFromSequence,
                                                .appendSequence])

        XCTAssertEqual(newCollection.history, [.initFromSequence,
                                               .appendSequence])
    }

    func testAppendSequenceOperatorSpecialization() {

        let baseCollection = TrackingCollection<Int>([1, 2, 3])
        let appendee = TrackingCollection<Int>([4, 5, 6, 7])

        XCTAssertEqual(baseCollection.history, [.initFromSequence])
        XCTAssertEqual(appendee.history, [.initFromSequence])

        let newCollection = makePublisher(baseCollection).append(appendee).sequence
        XCTAssertEqual(newCollection.storage, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(baseCollection.storage, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(appendee.storage, [4, 5, 6, 7])

        XCTAssertEqual(baseCollection.history, [.initFromSequence,
                                                .appendSequence])

        XCTAssertEqual(appendee.history, [.initFromSequence,
                                          .underestimatedCount,
                                          .makeIterator])

        XCTAssertEqual(newCollection.history, [.initFromSequence,
                                               .appendSequence])
    }

    func testAppendPublisherOperatorSpecialization() {
        let baseCollection = TrackingCollection<Int>([1, 2, 3])
        let appendee = TrackingCollection<Int>([4, 5, 6, 7])

        XCTAssertEqual(baseCollection.history, [.initFromSequence])
        XCTAssertEqual(appendee.history, [.initFromSequence])

        let newCollection = makePublisher(baseCollection)
            .append(makePublisher(appendee))
            .sequence
        XCTAssertEqual(newCollection.storage, [1, 2, 3, 4, 5, 6, 7] )
        XCTAssertEqual(baseCollection.storage, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(appendee.storage, [4, 5, 6, 7])

        XCTAssertEqual(baseCollection.history, [.initFromSequence,
                                                .appendSequence])

        XCTAssertEqual(appendee.history, [.initFromSequence,
                                          .underestimatedCount,
                                          .makeIterator])

        XCTAssertEqual(newCollection.history, [.initFromSequence,
                                               .appendSequence])
    }
}

private final class Counter: Sequence, IteratorProtocol, CustomStringConvertible {

    let upperBound: Int

    private(set) var state: Int

    init(upperBound: Int) {
        self.state = 0
        self.upperBound = upperBound
    }

    func makeIterator() -> Counter {
        return self
    }

    func next() -> Int? {
        defer {
            state += 1
        }

        return state >= upperBound ? nil : state
    }

    var description: String { return "Counter" }
}

/// This function is to prevent type ambiguity.
///
/// If both Foundation and OpenCombine are imported, Apple's Combine
/// extensions leak through Foundation, which results in the following error:
///
///     let publisher = [1, 2, 3, 4].publisher
///                     ^
///                     error: ambiguous use of 'publisher'
///
/// This could be fixed by explicitly specifying a type:
///
///     let publisher: OpenCombine.Publishers.Sequence = [1, 2, 3, 4].publisher
///
/// But this won't compile when testing compatibility, since compatibility tests
/// don't import OpenCombine. This could be fixed as well like this:
///
///     #if OPENCOMBINE_COMPATIBILITY_TEST
///     let publisher: Combine.Publishers.Sequence = [1, 2, 3, 4].publisher
///     #else
///     let publisher: OpenCombine.Publishers.Sequence = [1, 2, 3, 4].publisher
///     #endif
///
/// But this is too verbose. This function provides a more concise way:
///
///     let publisher = makePublisher([1, 2, 3, 4])
///
@available(macOS 10.15, iOS 13.0, *)
private func makePublisher<Elements: Sequence>(
    _ elements: Elements
) -> Publishers.Sequence<Elements, Never> {
    return elements.publisher
}
