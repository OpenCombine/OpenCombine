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

@available(macOS 10.15, *)
final class SequenceTests: XCTestCase {

    static let allTests = [
        ("testEmptySequence", testEmptySequence),
        ("testSequenceNoInitialDemand", testSequenceNoInitialDemand),
        ("testSequenceInitialDemand", testSequenceInitialDemand),
        ("testCancelOnSubscription", testCancelOnSubscription),
        ("testLifecycle", testLifecycle),
    ]

    func testEmptySequence() {

        let emptyCounter = Counter(upperBound: 0)

#if OPENCOMBINE_COMPATIBILITY_TEST
        let publisher: Combine.Publishers.Sequence = emptyCounter.publisher()
#else
        let publisher: OpenCombine.Publishers.Sequence = emptyCounter.publisher()
#endif

        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { subscription in
                XCTAssertEqual(String(describing: subscription), "Empty")
            }
        )

        XCTAssertEqual(emptyCounter.state, 0)

        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .completion(.finished)])
        XCTAssertEqual(emptyCounter.state, 1)
    }

    func testSequenceNoInitialDemand() throws {

        let counter = Counter(upperBound: 10)
#if OPENCOMBINE_COMPATIBILITY_TEST
        let publisher: Combine.Publishers.Sequence = counter.publisher()
#else
        let publisher: OpenCombine.Publishers.Sequence = counter.publisher()
#endif
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                XCTAssertEqual(String(describing: $0), "Counter")
                var reflected = ""
                dump($0, to: &reflected)
                XCTAssertEqual(reflected, """
                ▿ Counter #0
                  ▿ sequence: Counter #1
                    - upperBound: 10
                    - state: 2

                """)
            }
        )

        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty)])

        subscriber.subscriptions.first?.request(.max(3))

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(1),
                                            .value(2),
                                            .value(3)])

        subscriber.subscriptions.first?.request(.max(5))

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7),
                                            .value(8)])

        subscriber.subscriptions.first?.request(.none)

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7),
                                            .value(8)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
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
        ▿ Sequence #0
          - sequence: 0 elements

        """)
    }

    func testSequenceInitialDemand() {
        let counter = Counter(upperBound: 10)
#if OPENCOMBINE_COMPATIBILITY_TEST
        let publisher: Combine.Publishers.Sequence = counter.publisher()
#else
        let publisher: OpenCombine.Publishers.Sequence = counter.publisher()
#endif
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: {
                $0 > 4 || $0 == 1 ? .none : .max(2)
            }
        )

        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(1)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7),
                                            .value(8)])
    }

    func testCancelOnSubscription() {
        let counter = Counter(upperBound: 3)
#if OPENCOMBINE_COMPATIBILITY_TEST
        let publisher: Combine.Publishers.Sequence = counter.publisher()
#else
        let publisher: OpenCombine.Publishers.Sequence = counter.publisher()
#endif
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)); $0.cancel() }
        )
        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(1)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(1)])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = {
            deinitCounter += 1
        }

        do {
            let counter = Counter(upperBound: 3)
#if OPENCOMBINE_COMPATIBILITY_TEST
            let publisher: Combine.Publishers.Sequence = counter.publisher()
#else
            let publisher: OpenCombine.Publishers.Sequence = counter.publisher()
#endif
            let subscriber = TrackingSubscriberBase<Int, Never>(onDeinit: onDeinit)
            XCTAssertTrue(subscriber.history.isEmpty)

            publisher.subscribe(subscriber)
            XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty)])

            subscriber.subscriptions.first?.request(.max(3))
            XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                                .value(1),
                                                .value(2),
                                                .completion(.finished)])
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let counter = Counter(upperBound: 1)
#if OPENCOMBINE_COMPATIBILITY_TEST
            let publisher: Combine.Publishers.Sequence = counter.publisher()
#else
            let publisher: OpenCombine.Publishers.Sequence = counter.publisher()
#endif
            let subscriber = TrackingSubscriberBase<Int, Never>(
                receiveSubscription: { subscription = $0 },
                onDeinit: onDeinit
            )
            XCTAssertTrue(subscriber.history.isEmpty)
            publisher.subscribe(subscriber)
            XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty)])
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 1)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 2)
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
