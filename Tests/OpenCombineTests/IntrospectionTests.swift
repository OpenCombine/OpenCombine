//
//  IntrospectionTests.swift
//  OpenCombineTests
//
//  Created by Sergej Jaskiewicz on 27.09.2020.
//

//
//  PublisherTests.swift
//
//
//  Created by Sergej Jaskiewicz on 08.07.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 11.0, iOS 14.0, *)
final class IntrospectionTests: XCTestCase {

    func testSubscribe() {

        let introspection = TrackingIntrospection()
        let customSubscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: customSubscription)
        let tracking = TrackingSubscriber()

        var subscribers = [Any]()

        publisher.willSubscribe = {
            subscribers.append($1)
        }

        func subscribe() {
            // This should not be tracked by the introspection object
            publisher.receive(subscriber: tracking)

            publisher.subscribe(tracking)
        }

        subscribe()
        introspection.enable()
        defer { introspection.disable() }
        subscribe()
        introspection.disable()
        publisher.send(subscription: customSubscription)
        subscribe()

        XCTAssertEqual(
            introspection.history,
            [.publisherWillReceiveSubscriber(.init(publisher), .init(tracking)),
             .subscriberWillReceiveSubscription(.init(tracking),
                                                .init(customSubscription)),
             .subscriberDidReceiveSubscription(.init(tracking),
                                               .init(customSubscription)),
             .publisherDidReceiveSubscriber(.init(publisher), .init(tracking))]
        )
        XCTAssertEqual(customSubscription.history, [])
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .subscription("CustomSubscription"),
                                          .subscription("CustomSubscription"),
                                          .subscription("CustomSubscription"),
                                          .subscription("CustomSubscription"),
                                          .subscription("CustomSubscription"),
                                          .subscription("CustomSubscription")])

        for case let (i, .subscription(.subscription(subscription))) in
            tracking.history.enumerated()
        {
            if i == 3 || i == 4 {
                XCTAssertFalse(subscription is CustomSubscription,
                               """
                               Introspection injects its own subscription that forwards \
                               method calls to the original subscription
                               """)
                XCTAssertTrue(subscription is CustomStringConvertible)
                XCTAssertFalse(subscription is CustomDebugStringConvertible)
                XCTAssertFalse(subscription is CustomReflectable)
                XCTAssertFalse(subscription is CustomPlaygroundDisplayConvertible)
                XCTAssertEqual(subscription.combineIdentifier,
                               customSubscription.combineIdentifier)
            } else {
                XCTAssertTrue(subscription is CustomSubscription)
            }
        }

        for (i, subscriber) in subscribers.enumerated() {
            if i == 3 {
                XCTAssertFalse(subscriber as AnyObject === tracking,
                               """
                               Introspection injects its own subscriber that forwards \
                               method calls to the original subscriber
                               """)
                XCTAssertFalse(subscriber is AnySubscriber<Int, TestingError>)
                XCTAssertEqual((subscriber as? CustomStringConvertible)?.description,
                               tracking.description)
                XCTAssertFalse(subscriber is CustomDebugStringConvertible)
                XCTAssertFalse(subscriber is CustomReflectable)
                XCTAssertFalse(subscriber is CustomPlaygroundDisplayConvertible)
                XCTAssertEqual(
                    (subscriber as? CustomCombineIdentifierConvertible)?
                        .combineIdentifier,
                    tracking.combineIdentifier
                )
            } else {
                XCTAssertTrue(subscriber as AnyObject === tracking)
            }
        }
    }

    func testReceiveInput() {
        let introspection1 = TrackingIntrospection()

        // Test that two independent instrospection objects don't affect each other
        let introspection2 = TrackingIntrospection()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber(receiveValue: { .max($0 + 1) })

        var counter = 1

        func sendInput() {
            XCTAssertEqual(publisher.send(counter), .max(counter + 1))
            counter += 1
        }

        XCTAssertFalse(introspection1.isEnabled)
        XCTAssertFalse(introspection2.isEnabled)
        introspection1.enable()
        defer { introspection1.disable() }
        XCTAssertTrue(introspection1.isEnabled)
        XCTAssertFalse(introspection2.isEnabled)
        publisher.subscribe(tracking)

        sendInput()
        sendInput()
        introspection2.enable()
        defer { introspection2.disable() }
        XCTAssertTrue(introspection1.isEnabled)
        XCTAssertTrue(introspection2.isEnabled)
        sendInput()
        introspection1.disable()
        XCTAssertFalse(introspection1.isEnabled)
        XCTAssertTrue(introspection2.isEnabled)
        sendInput()
        sendInput()
        introspection2.disable()
        XCTAssertFalse(introspection1.isEnabled)
        XCTAssertFalse(introspection2.isEnabled)
        sendInput()

        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .value(5),
                                          .value(6)])
        XCTAssertEqual(
            introspection1.history,
            [.publisherWillReceiveSubscriber(.init(publisher), .init(tracking)),
             .subscriberWillReceiveSubscription(.init(tracking), .init(subscription)),
             .subscriberDidReceiveSubscription(.init(tracking), .init(subscription)),
             .publisherDidReceiveSubscriber(.init(publisher), .init(tracking)),
             .subscriberWillReceiveInput(.init(tracking), 1),
             .subscriberDidReceiveInput(.init(tracking), 1, .max(2)),
             .subscriberWillReceiveInput(.init(tracking), 2),
             .subscriberDidReceiveInput(.init(tracking), 2, .max(3)),
             .subscriberWillReceiveInput(.init(tracking), 3),
             .subscriberDidReceiveInput(.init(tracking), 3, .max(4))]
        )
        XCTAssertEqual(introspection2.history,
                       [.subscriberWillReceiveInput(.init(tracking), 3),
                        .subscriberDidReceiveInput(.init(tracking), 3, .max(4)),
                        .subscriberWillReceiveInput(.init(tracking), 4),
                        .subscriberDidReceiveInput(.init(tracking), 4, .max(5)),
                        .subscriberWillReceiveInput(.init(tracking), 5),
                        .subscriberDidReceiveInput(.init(tracking), 5, .max(6))])
    }

    func testReceiveCompletion() {
        let introspection1 = TrackingIntrospection()

        // Test that two independent instrospection objects don't affect each other
        let introspection2 = TrackingIntrospection()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber()

        var counter = 1

        func sendCompletion() {
            publisher.send(completion: .finished)
            publisher.send(completion: .failure(.init(description: "oops \(counter)")))
            counter += 1
        }

        introspection1.enable()
        defer { introspection1.disable() }

        publisher.subscribe(tracking)

        sendCompletion()
        sendCompletion()
        introspection2.enable()
        defer { introspection2.disable() }
        sendCompletion()
        introspection1.disable()
        sendCompletion()
        sendCompletion()
        introspection2.disable()
        sendCompletion()

        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .completion(.finished),
                                          .completion(.failure("oops 1")),
                                          .completion(.finished),
                                          .completion(.failure("oops 2")),
                                          .completion(.finished),
                                          .completion(.failure("oops 3")),
                                          .completion(.finished),
                                          .completion(.failure("oops 4")),
                                          .completion(.finished),
                                          .completion(.failure("oops 5")),
                                          .completion(.finished),
                                          .completion(.failure("oops 6"))])
        XCTAssertEqual(
            introspection1.history,
            [.publisherWillReceiveSubscriber(.init(publisher), .init(tracking)),
             .subscriberWillReceiveSubscription(.init(tracking), .init(subscription)),
             .subscriberDidReceiveSubscription(.init(tracking), .init(subscription)),
             .publisherDidReceiveSubscriber(.init(publisher), .init(tracking)),
             .subscriberWillReceiveCompletion(.init(tracking), .finished),
             .subscriberDidReceiveCompletion(.init(tracking), .finished),
             .subscriberWillReceiveCompletion(.init(tracking), .failure("oops 1")),
             .subscriberDidReceiveCompletion(.init(tracking), .failure("oops 1")),
             .subscriberWillReceiveCompletion(.init(tracking), .finished),
             .subscriberDidReceiveCompletion(.init(tracking), .finished),
             .subscriberWillReceiveCompletion(.init(tracking), .failure("oops 2")),
             .subscriberDidReceiveCompletion(.init(tracking), .failure("oops 2")),
             .subscriberWillReceiveCompletion(.init(tracking), .finished),
             .subscriberDidReceiveCompletion(.init(tracking), .finished),
             .subscriberWillReceiveCompletion(.init(tracking), .failure("oops 3")),
             .subscriberDidReceiveCompletion(.init(tracking), .failure("oops 3"))]
        )
        XCTAssertEqual(
            introspection2.history,
            [.subscriberWillReceiveCompletion(.init(tracking), .finished),
             .subscriberDidReceiveCompletion(.init(tracking), .finished),
             .subscriberWillReceiveCompletion(.init(tracking), .failure("oops 3")),
             .subscriberDidReceiveCompletion(.init(tracking), .failure("oops 3")),
             .subscriberWillReceiveCompletion(.init(tracking), .finished),
             .subscriberDidReceiveCompletion(.init(tracking), .finished),
             .subscriberWillReceiveCompletion(.init(tracking), .failure("oops 4")),
             .subscriberDidReceiveCompletion(.init(tracking), .failure("oops 4")),
             .subscriberWillReceiveCompletion(.init(tracking), .finished),
             .subscriberDidReceiveCompletion(.init(tracking), .finished),
             .subscriberWillReceiveCompletion(.init(tracking), .failure("oops 5")),
             .subscriberDidReceiveCompletion(.init(tracking), .failure("oops 5"))]
        )
    }

    func testRequest() throws {
        let introspection1 = TrackingIntrospection()

        // Test that two independent instrospection objects don't affect each other
        let introspection2 = TrackingIntrospection()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )

        var counter = 1

        func request() throws {
            try XCTUnwrap(downstreamSubscription).request(.max(counter))
            counter += 1
        }

        introspection1.enable()
        defer { introspection1.disable() }

        publisher.subscribe(tracking)

        try request()
        try request()
        introspection2.enable()
        defer { introspection2.disable() }
        try request()
        introspection1.disable()
        try request()
        try request()
        introspection2.disable()
        try request()

        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .requested(.max(2)),
                                              .requested(.max(3)),
                                              .requested(.max(4)),
                                              .requested(.max(5)),
                                              .requested(.max(6))])
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])
        XCTAssertEqual(
            introspection1.history,
            [.publisherWillReceiveSubscriber(.init(publisher), .init(tracking)),
             .subscriberWillReceiveSubscription(.init(tracking), .init(subscription)),
             .subscriberDidReceiveSubscription(.init(tracking), .init(subscription)),
             .publisherDidReceiveSubscriber(.init(publisher), .init(tracking)),
             .willRequestDemand(.init(subscription), .max(1)),
             .didRequestDemand(.init(subscription), .max(1)),
             .willRequestDemand(.init(subscription), .max(2)),
             .didRequestDemand(.init(subscription), .max(2)),
             .willRequestDemand(.init(subscription), .max(3)),
             .didRequestDemand(.init(subscription), .max(3))]
        )
        XCTAssertEqual(introspection2.history,
                       [.willRequestDemand(.init(subscription), .max(3)),
                        .didRequestDemand(.init(subscription), .max(3)),
                        .willRequestDemand(.init(subscription), .max(4)),
                        .didRequestDemand(.init(subscription), .max(4)),
                        .willRequestDemand(.init(subscription), .max(5)),
                        .didRequestDemand(.init(subscription), .max(5))])
    }

    func testCancel() throws {
        let introspection1 = TrackingIntrospection()

        // Test that two independent instrospection objects don't affect each other
        let introspection2 = TrackingIntrospection()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )

        func cancel() throws {
            try XCTUnwrap(downstreamSubscription).cancel()
        }

        introspection1.enable()
        defer { introspection1.disable() }
        publisher.subscribe(tracking)

        try cancel()
        try cancel()
        introspection2.enable()
        defer { introspection2.disable() }
        try cancel()
        introspection1.disable()
        try cancel()
        introspection2.disable()
        try cancel()

        XCTAssertEqual(subscription.history, [.cancelled,
                                              .cancelled,
                                              .cancelled,
                                              .cancelled,
                                              .cancelled])
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])
        XCTAssertEqual(
            introspection1.history,
            [.publisherWillReceiveSubscriber(.init(publisher), .init(tracking)),
             .subscriberWillReceiveSubscription(.init(tracking), .init(subscription)),
             .subscriberDidReceiveSubscription(.init(tracking), .init(subscription)),
             .publisherDidReceiveSubscriber(.init(publisher), .init(tracking)),
             .willCancel(.init(subscription)),
             .didCancel(.init(subscription)),
             .willCancel(.init(subscription)),
             .didCancel(.init(subscription)),
             .willCancel(.init(subscription)),
             .didCancel(.init(subscription))]
        )
        XCTAssertEqual(introspection2.history,
                       [.willCancel(.init(subscription)),
                        .didCancel(.init(subscription)),
                        .willCancel(.init(subscription)),
                        .didCancel(.init(subscription))])
    }

    func testWithTryFilterOperator() {
        // This operator has its own subscription object, which it sends downstream.
        // This is a use case we want to test.

        let introspection1 = TrackingIntrospection()

        // Test that two independent instrospection objects don't affect each other
        let introspection2 = TrackingIntrospection()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriberBase<Int, Error>(receiveValue: { .max($0 + 1) })

        var counter = 1

        func sendInput() {
            _ = publisher.send(counter)
            counter += 1
        }

        introspection1.enable()
        defer { introspection1.disable() }
        let tryFilterPublisher = publisher.tryFilter { $0.isMultiple(of: 2) }
        tryFilterPublisher.subscribe(tracking)

        sendInput()
        sendInput()
        sendInput()
        sendInput()
        introspection2.enable()
        defer { introspection2.disable() }
        sendInput()
        sendInput()
        introspection1.disable()
        sendInput()
        sendInput()
        sendInput()
        sendInput()
        introspection2.disable()
        sendInput()
        sendInput()

        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(tracking.history, [.subscription("TryFilter"),
                                          .value(2),
                                          .value(4),
                                          .value(6),
                                          .value(8),
                                          .value(10),
                                          .value(12)])
        XCTAssertEqual(
            introspection1.history,
            [.publisherWillReceiveSubscriber(.init(tryFilterPublisher), .init(tracking)),
             .publisherWillReceiveSubscriber(.init(publisher), "TryFilter"),
             .subscriberWillReceiveSubscription("TryFilter", .init(subscription)),
             .subscriberWillReceiveSubscription(.init(tracking), "TryFilter"),
             .subscriberDidReceiveSubscription(.init(tracking), "TryFilter"),
             .subscriberDidReceiveSubscription("TryFilter", .init(subscription)),
             .publisherDidReceiveSubscriber(.init(publisher), "TryFilter"),
             .publisherDidReceiveSubscriber(.init(tryFilterPublisher), .init(tracking)),
             .subscriberWillReceiveInput("TryFilter", 1),
             .subscriberDidReceiveInput("TryFilter", 1, .max(1)),
             .subscriberWillReceiveInput("TryFilter", 2),
             .subscriberWillReceiveInput(.init(tracking), 2),
             .subscriberDidReceiveInput(.init(tracking), 2, .max(3)),
             .subscriberDidReceiveInput("TryFilter", 2, .max(3)),
             .subscriberWillReceiveInput("TryFilter", 3),
             .subscriberDidReceiveInput("TryFilter", 3, .max(1)),
             .subscriberWillReceiveInput("TryFilter", 4),
             .subscriberWillReceiveInput(.init(tracking), 4),
             .subscriberDidReceiveInput(.init(tracking), 4, .max(5)),
             .subscriberDidReceiveInput("TryFilter", 4, .max(5)),
             .subscriberWillReceiveInput("TryFilter", 5),
             .subscriberDidReceiveInput("TryFilter", 5, .max(1)),
             .subscriberWillReceiveInput("TryFilter", 6),
             .subscriberWillReceiveInput(.init(tracking), 6),
             .subscriberDidReceiveInput(.init(tracking), 6, .max(7)),
             .subscriberDidReceiveInput("TryFilter", 6, .max(7))]
        )
        XCTAssertEqual(introspection2.history,
                       [.subscriberWillReceiveInput("TryFilter", 5),
                        .subscriberDidReceiveInput("TryFilter", 5, .max(1)),
                        .subscriberWillReceiveInput("TryFilter", 6),
                        .subscriberWillReceiveInput(.init(tracking), 6),
                        .subscriberDidReceiveInput(.init(tracking), 6, .max(7)),
                        .subscriberDidReceiveInput("TryFilter", 6, .max(7)),
                        .subscriberWillReceiveInput("TryFilter", 7),
                        .subscriberDidReceiveInput("TryFilter", 7, .max(1)),
                        .subscriberWillReceiveInput("TryFilter", 8),
                        .subscriberWillReceiveInput(.init(tracking), 8),
                        .subscriberDidReceiveInput(.init(tracking), 8, .max(9)),
                        .subscriberDidReceiveInput("TryFilter", 8, .max(9)),
                        .subscriberWillReceiveInput("TryFilter", 9),
                        .subscriberDidReceiveInput("TryFilter", 9, .max(1)),
                        .subscriberWillReceiveInput("TryFilter", 10),
                        .subscriberWillReceiveInput(.init(tracking), 10),
                        .subscriberDidReceiveInput(.init(tracking), 10, .max(11)),
                        .subscriberDidReceiveInput("TryFilter", 10, .max(11))])
    }

    func testWithMapOperator() {
        // This operator doesn't have own subscription object. Instead, it sends
        // downstream the subscription object that it received from the upstream.
        // This is a use case we want to test as well.

        let introspection1 = TrackingIntrospection()

        // Test that two independent instrospection objects don't affect each other
        let introspection2 = TrackingIntrospection()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber(receiveValue: { .max($0 + 1) })

        var counter = 1

        func sendInput() {
            _ = publisher.send(counter)
            counter += 1
        }

        introspection1.enable()
        defer { introspection1.disable() }
        let mapPublisher = publisher.map { $0 * 2 }
        mapPublisher.subscribe(tracking)

        sendInput()
        sendInput()
        introspection2.enable()
        defer { introspection2.disable() }
        sendInput()
        introspection1.disable()
        sendInput()
        sendInput()
        introspection2.disable()
        sendInput()

        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .value(2),
                                          .value(4),
                                          .value(6),
                                          .value(8),
                                          .value(10),
                                          .value(12)])
        XCTAssertEqual(
            introspection1.history,
            [.publisherWillReceiveSubscriber(.init(mapPublisher), .init(tracking)),
             .publisherWillReceiveSubscriber(.init(publisher), "Map"),
             .subscriberWillReceiveSubscription("Map", .init(subscription)),
             .subscriberWillReceiveSubscription(.init(tracking), .init(subscription)),
             .subscriberDidReceiveSubscription(.init(tracking), .init(subscription)),
             .subscriberDidReceiveSubscription("Map", .init(subscription)),
             .publisherDidReceiveSubscriber(.init(publisher), "Map"),
             .publisherDidReceiveSubscriber(.init(mapPublisher), .init(tracking)),
             .subscriberWillReceiveInput("Map", 1),
             .subscriberWillReceiveInput(.init(tracking), 2),
             .subscriberDidReceiveInput(.init(tracking), 2, .max(3)),
             .subscriberDidReceiveInput("Map", 1, .max(3)),
             .subscriberWillReceiveInput("Map", 2),
             .subscriberWillReceiveInput(.init(tracking), 4),
             .subscriberDidReceiveInput(.init(tracking), 4, .max(5)),
             .subscriberDidReceiveInput("Map", 2, .max(5)),
             .subscriberWillReceiveInput("Map", 3),
             .subscriberWillReceiveInput(.init(tracking), 6),
             .subscriberDidReceiveInput(.init(tracking), 6, .max(7)),
             .subscriberDidReceiveInput("Map", 3, .max(7))]
        )
        XCTAssertEqual(
            introspection2.history,
            [.subscriberWillReceiveInput("Map", 3),
             .subscriberWillReceiveInput(.init(tracking), 6),
             .subscriberDidReceiveInput(.init(tracking), 6, .max(7)),
             .subscriberDidReceiveInput("Map", 3, .max(7)),
             .subscriberWillReceiveInput("Map", 4),
             .subscriberWillReceiveInput(.init(tracking), 8),
             .subscriberDidReceiveInput(.init(tracking), 8, .max(9)),
             .subscriberDidReceiveInput("Map", 4, .max(9)),
             .subscriberWillReceiveInput("Map", 5),
             .subscriberWillReceiveInput(.init(tracking), 10),
             .subscriberDidReceiveInput(.init(tracking), 10, .max(11)),
             .subscriberDidReceiveInput("Map", 5, .max(11))]
        )
    }

    func testNoopOperator() {
        let introspection = TrackingIntrospection()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber(receiveValue: { .max($0 + 1) })

        var counter = 1

        func sendInput() {
            XCTAssertEqual(publisher.send(counter), .max(counter + 1))
            counter += 1
        }

        introspection.enable()
        defer { introspection.disable() }

        let noop = publisher.noop()
        noop.subscribe(tracking)

        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])
        XCTAssertEqual(
            introspection.history,
            [.publisherWillReceiveSubscriber(.init(noop), .init(tracking)),
             .publisherWillReceiveSubscriber(.init(publisher), .init(tracking)),
             .subscriberWillReceiveSubscription(.init(tracking), .init(subscription)),
             .subscriberDidReceiveSubscription(.init(tracking), .init(subscription)),
             .publisherDidReceiveSubscriber(.init(publisher), .init(tracking)),
             .publisherDidReceiveSubscriber(.init(noop), .init(tracking))]
        )

        guard introspection.history.count == 6 else { return }

        if case let .publisherWillReceiveSubscriber(_, subscriber) =
            introspection.history[0]
        {
            XCTAssertTrue(
                try XCTUnwrap(subscriber.underlying) is TrackingSubscriber
            )
        }

        if case let .publisherWillReceiveSubscriber(_, subscriber) =
            introspection.history[1]
        {
            XCTAssertTrue(
                try XCTUnwrap(subscriber.underlying) is AnySubscriber<Int, TestingError>
            )
        }

        if case let .subscriberWillReceiveSubscription(subscriber, _) =
            introspection.history[2]
        {
            XCTAssertTrue(
                try XCTUnwrap(subscriber.underlying) is TrackingSubscriber
            )
        }

        if case let .subscriberDidReceiveSubscription(subscriber, _) =
            introspection.history[3]
        {
            XCTAssertTrue(
                try XCTUnwrap(subscriber.underlying) is TrackingSubscriber
            )
        }

        if case let .publisherDidReceiveSubscriber(_, subscriber) =
            introspection.history[4]
        {
            XCTAssertTrue(
                try XCTUnwrap(subscriber.underlying) is AnySubscriber<Int, TestingError>
            )
        }

        if case let .publisherDidReceiveSubscriber(_, subscriber) =
            introspection.history[5]
        {
            XCTAssertTrue(
                try XCTUnwrap(subscriber.underlying) is TrackingSubscriber
            )
        }
    }
}

@available(macOS 11.0, iOS 14.0, *)
private struct Noop<Upstream: Publisher>: Publisher {
    typealias Output = Upstream.Output
    typealias Failure = Upstream.Failure

    let upstream: Upstream

    func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Failure == Failure, Downstream.Input == Output
    {
        upstream.subscribe(subscriber)
    }
}

@available(macOS 11.0, iOS 14.0, *)
extension Publisher {
    fileprivate func noop() -> Noop<Self> {
        return .init(upstream: self)
    }
}
