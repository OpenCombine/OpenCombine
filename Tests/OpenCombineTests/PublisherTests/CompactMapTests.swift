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

    func testEmpty() {
        let tracking = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubject<String>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "CompactMap")
            }
        )

        publisher.compactMap(Int.init).subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("CompactMap")])
    }

    func testError() {
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher =
            CustomPublisherBase<String, TestingError>(subscription: CustomSubscription())

        publisher.compactMap(Int.init).subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        publisher.send(completion: .failure(expectedError))

        XCTAssertEqual(tracking.history, [.subscription("CompactMap"),
                                          .completion(.failure(.oops))])
    }

    func testTryMapFailureBecauseOfThrow() {
        var counter = 0 // How many times the transform is called?

        let publisher = PassthroughSubject<String, Error>()
        let compactMap = publisher.tryCompactMap { value -> Int? in
            counter += 1
            if value == "throw" {
                throw "too much" as TestingError
            }
            return Int(value)
        }
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.send("1")
        compactMap.subscribe(tracking)
        publisher.send("2")
        publisher.send("3")
        publisher.send("throw")
        publisher.send("9")
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryCompactMap"),
                        .value(2),
                        .value(3),
                        .completion(.failure("too much" as TestingError))])

        XCTAssertEqual(counter, 3)
    }

    func testTryMapFailureOnCompletion() {

        let publisher = PassthroughSubject<String, Error>()
        let compactMap = publisher.tryCompactMap(Int.init)

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send("1")
        compactMap.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        publisher.send("2")

        XCTAssertEqual(tracking.history,
                       [.subscription("TryCompactMap"),
                        .completion(.failure(TestingError.oops))])
    }

    func testRange() {

        let publisher = PassthroughSubject<String, TestingError>()
        let compactMap = publisher.compactMap(Int.init)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        publisher.send("1")
        compactMap.subscribe(tracking)
        publisher.send("2")
        publisher.send("a")
        publisher.send("b")
        publisher.send("a")
        publisher.send("3")
        publisher.send("4")
        publisher.send("5")
        publisher.send("!")
        publisher.send(completion: .finished)
        publisher.send("6")

        XCTAssertEqual(tracking.history, [.subscription("CompactMap"),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .value(5),
                                          .completion(.finished)])
    }

    func testNoDemand() {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<String, TestingError>(subscription: subscription)
        let compactMap = publisher.compactMap(Int.init)
        let tracking = TrackingSubscriber()
        compactMap.subscribe(tracking)
        XCTAssertTrue(subscription.history.isEmpty)
    }

    func testDemandOnSubscribe() {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<String, TestingError>(subscription: subscription)
        let compactMap = publisher.compactMap(Int.init)
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(42)) }
        )
        compactMap.subscribe(tracking)
        XCTAssertEqual(subscription.history, [.requested(.max(42))])
    }

    func testDemand() {

        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<String, TestingError>(subscription: subscription)
        let compactMap = publisher.compactMap(Int.init)
        var downstreamSubscription: Subscription?

        var demandOnReceiveValue = Subscribers.Demand.max(3)
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(5))
                downstreamSubscription = $0
            },
            receiveValue: { _ in demandOnReceiveValue }
        )

        compactMap.subscribe(tracking)

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
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5)),
                                              .requested(.max(121)),
                                              .cancelled])
        downstreamSubscription?.request(.max(3))
        XCTAssertEqual(subscription.history, [.requested(.max(5)),
                                              .requested(.max(15)),
                                              .requested(.max(5)),
                                              .requested(.max(121)),
                                              .cancelled])
        demandOnReceiveValue = .max(80)
        XCTAssertEqual(publisher.send("8"), .none)
    }

    func testCompletion() {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<String, TestingError>(subscription: subscription)
        let compactMap = publisher.compactMap(Int.init)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        compactMap.subscribe(tracking)
        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("CompactMap"),
                                          .completion(.finished)])
    }

    func testCompactMapCancel() throws {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<String, TestingError>(subscription: subscription)
        let compactMap = publisher.compactMap(Int.init)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.unlimited)
                downstreamSubscription = $0
            }
        )

        compactMap.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send("1"), .none)
        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testTryCompactMapCancel() throws {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<String, TestingError>(subscription: subscription)
        let tryCompactMap = publisher.tryCompactMap(Int.init)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: {
                $0.request(.unlimited)
                downstreamSubscription = $0
            }
        )

        tryCompactMap.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send("1"), .none)
        publisher.send(completion: .finished)
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testCancelAlreadyCancelled() throws {
        let subscription = CustomSubscription()
        let publisher =
            CustomPublisherBase<String, TestingError>(subscription: subscription)
        let compactMap = publisher.compactMap(Int.init)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.unlimited)
                downstreamSubscription = $0
            }
        )

        compactMap.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = { deinitCounter += 1 }

        do {
            let passthrough = PassthroughSubject<String, TestingError>()
            let compactMap = passthrough.compactMap(Int.init)
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            compactMap.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send("31")
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        XCTAssertEqual(deinitCounter, 0)

        do {
            let passthrough = PassthroughSubject<String, TestingError>()
            let compactMap = passthrough.compactMap(Int.init)
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            compactMap.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 0)

        var subscription: Subscription?

        do {
            let passthrough = PassthroughSubject<String, TestingError>()
            let compactMap = passthrough.compactMap(Int.init)
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            compactMap.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send("31")
            XCTAssertEqual(emptySubscriber.inputs.count, 1)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 0)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 0)
    }

    func testCompactMapOperatorSpecializationForCompactMap() {
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<String, TestingError>()

        let compactMap1 = publisher.compactMap(Int.init)
        let compactMap2 = compactMap1.compactMap { $0.isMultiple(of: 2) ? $0 / 2 : nil }

        compactMap2.subscribe(tracking)
        publisher.send("0")
        publisher.send("3")
        publisher.send("a")
        publisher.send("12")
        publisher.send("11")
        publisher.send("20")
        publisher.send("b")
        publisher.send(completion: .finished)

        XCTAssert(compactMap1.upstream === compactMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("CompactMap"),
                                          .value(0),
                                          .value(6),
                                          .value(10),
                                          .completion(.finished)])
    }

    func testMapOperatorSpecializationForCompactMap() {
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = PassthroughSubject<String, TestingError>()

        let compactMap1 = publisher.compactMap(Int.init)
        let compactMap2 = compactMap1.map { $0 + 1 }

        compactMap2.subscribe(tracking)
        publisher.send("0")
        publisher.send("3")
        publisher.send("a")
        publisher.send("12")
        publisher.send("11")
        publisher.send("20")
        publisher.send("b")
        publisher.send(completion: .finished)

        XCTAssert(compactMap1.upstream === compactMap2.upstream)
        XCTAssertEqual(tracking.history, [.subscription("CompactMap"),
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
