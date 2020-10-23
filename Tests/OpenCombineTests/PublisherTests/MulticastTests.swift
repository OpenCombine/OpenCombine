//
//  MulticastTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MulticastTests: XCTestCase {

    func testMulticast() throws {
        try MulticastTests.testGenericMulticast { $0.multicast(PassthroughSubject.init) }
    }

    func testMulticastConnectTwice() {
        MulticastTests.testGenericMulticastConnectTwice {
            $0.multicast { TrackingSubjectBase<Int, Never>() }
        }
    }

    func testMulticastDisconnect() {
        MulticastTests.testGenericMulticastDisconnect {
            $0.multicast(PassthroughSubject.init)
        }
    }

    func testLateSubscriber() {
        let subscription = CustomSubscription()

        let publisher = CustomPublisher(subscription: subscription)

        let subject = TrackingSubject<Int>()

        let multicast = publisher.multicast(subject: subject)

        XCTAssert(subject.history.isEmpty)

        let earlySubscriber = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(3))
            }
        )

        multicast.subscribe(earlySubscriber)

        XCTAssertNil(publisher.subscriber)
        XCTAssertEqual(earlySubscriber.history, [.subscription("Multicast")])

        XCTAssertEqual(subject.history, [.subscriber])

        let connection = multicast.connect()

        XCTAssert(connection is AnyCancellable)
        XCTAssertNotNil(publisher.subscriber)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(earlySubscriber.history, [.subscription("Multicast")])
        XCTAssertEqual(subject.history, [.subscriber, .subscription("Subject")])

        XCTAssertEqual(publisher.send(1), .none)
        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(publisher.send(3), .none)
        XCTAssertEqual(publisher.send(4), .none)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(earlySubscriber.history, [.subscription("Multicast"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3)])
        XCTAssertEqual(subject.history, [.subscriber,
                                         .subscription("Subject"),
                                         .value(1),
                                         .value(2),
                                         .value(3),
                                         .value(4)])

        let lateSubscriber = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(2))
            }
        )

        multicast.subscribe(lateSubscriber)

        XCTAssertEqual(publisher.send(5), .none)
        XCTAssertEqual(publisher.send(6), .none)
        XCTAssertEqual(publisher.send(7), .none)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(earlySubscriber.history, [.subscription("Multicast"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3)])
        XCTAssertEqual(lateSubscriber.history, [.subscription("Multicast"),
                                                .value(5),
                                                .value(6)])
        XCTAssertEqual(subject.history, [.subscriber,
                                         .subscription("Subject"),
                                         .value(1),
                                         .value(2),
                                         .value(3),
                                         .value(4),
                                         .subscriber,
                                         .value(5),
                                         .value(6),
                                         .value(7)])

        publisher.send(completion: .finished)

        let latestSubscriber = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.none)
            }
        )

        multicast.subscribe(latestSubscriber)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(earlySubscriber.history, [.subscription("Multicast"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .completion(.finished)])
        XCTAssertEqual(lateSubscriber.history, [.subscription("Multicast"),
                                                .value(5),
                                                .value(6),
                                                .completion(.finished)])
        XCTAssertEqual(latestSubscriber.history, [.subscription("Multicast"),
                                                  .completion(.finished)])
        XCTAssertEqual(subject.history, [.subscriber,
                                         .subscription("Subject"),
                                         .value(1),
                                         .value(2),
                                         .value(3),
                                         .value(4),
                                         .subscriber,
                                         .value(5),
                                         .value(6),
                                         .value(7),
                                         .completion(.finished),
                                         .subscriber])

        connection.cancel()
    }

    func testSubscribeAfterCompletion() {

        let publisher = CustomPublisher(subscription: CustomSubscription())

        let subject = MulticastTestingSubject()

        let multicast = publisher.multicast(subject: subject)

        _ = multicast.connect()

        publisher.send(completion: .finished)

        let lateSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )

        multicast.subscribe(lateSubscriber)

        XCTAssertEqual(lateSubscriber.history, [.subscription("Multicast")])
    }

    func testInnerSubscriber() throws {

        let publisher = PassthroughSubject<Int, TestingError>()

        let subject = MulticastTestingSubject()

        let multicast = publisher.multicast(subject: subject)
        let subscriber = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.max(42)) },
            receiveValue: { $0 < 0 ? .unlimited : .max($0) }
        )

        try withExtendedLifetime(multicast.connect()) {
            multicast.subscribe(subscriber)

            XCTAssertEqual(subscriber.history, [.subscription("Multicast")])
            XCTAssertEqual(subject.subscription.history, [.requested(.max(42))])

            // Steal the underlying Multicast subscriber/subscription
            let innerSubscriber = try XCTUnwrap(subject.subscriber)

            innerSubscriber.receive(subscription: Subscriptions.empty)
            innerSubscriber.receive(subscription: Subscriptions.empty)

            XCTAssertEqual(subscriber.history,
                           [.subscription("Multicast")],
                           "Downstream subscriber should receive subscription once")
            XCTAssertEqual(subject.subscription.history, [.requested(.max(42))])

            XCTAssertEqual(innerSubscriber.receive(0), .none)
            XCTAssertEqual(innerSubscriber.receive(0), .none)
            XCTAssertEqual(innerSubscriber.receive(1), .none)
            XCTAssertEqual(innerSubscriber.receive(2), .none)
            XCTAssertEqual(innerSubscriber.receive(-1), .none)
            XCTAssertEqual(innerSubscriber.receive(3), .none)
            XCTAssertEqual(innerSubscriber.receive(-1), .none)
            XCTAssertEqual(innerSubscriber.receive(0), .none)

            XCTAssertEqual(subscriber.history, [.subscription("Multicast"),
                                                .value(0),
                                                .value(0),
                                                .value(1),
                                                .value(2),
                                                .value(-1),
                                                .value(3),
                                                .value(-1),
                                                .value(0)])
            XCTAssertEqual(subject.subscription.history, [.requested(.max(42)),
                                                          .requested(.max(1)),
                                                          .requested(.max(2)),
                                                          .requested(.unlimited),
                                                          .requested(.max(3)),
                                                          .requested(.unlimited)])

            innerSubscriber.receive(completion: .failure(.oops))
            innerSubscriber.receive(completion: .finished)
            XCTAssertEqual(innerSubscriber.receive(123), .none)
            innerSubscriber.receive(subscription: Subscriptions.empty)

            XCTAssertEqual(subscriber.history, [.subscription("Multicast"),
                                                .value(0),
                                                .value(0),
                                                .value(1),
                                                .value(2),
                                                .value(-1),
                                                .value(3),
                                                .value(-1),
                                                .value(0),
                                                .completion(.failure(.oops))])
        }
    }

    func testInnerSubscription() throws {
        let publisher = PassthroughSubject<Int, TestingError>()

        let subject = MulticastTestingSubject()

        let multicast = publisher.multicast(subject: subject)
        let subscriber = TrackingSubscriberBase<Int, TestingError>()

        try withExtendedLifetime(multicast.connect()) {
            multicast.subscribe(subscriber)

            XCTAssertEqual(subscriber.history, [.subscription("Multicast")])
            XCTAssertEqual(subject.subscription.history, [])

            // Steal the underlying Multicast subscriber/subscription
            let innerSubscriber = try XCTUnwrap(subject.subscriber)
            let innerSubscription =
                try XCTUnwrap(subscriber.subscriptions.first?.underlying)

            innerSubscription.request(.max(42))
            innerSubscription.request(.max(43))
            innerSubscription.request(.unlimited)
            innerSubscription.request(.max(44))

            XCTAssertEqual(subject.subscription.history, [.requested(.max(42)),
                                                          .requested(.max(43)),
                                                          .requested(.unlimited),
                                                          .requested(.max(44))])
            XCTAssertEqual(subscriber.history, [.subscription("Multicast")])

            innerSubscription.cancel()
            innerSubscription.cancel()
            innerSubscription.request(.max(30))
            innerSubscription.request(.unlimited)
            innerSubscriber.receive(subscription: Subscriptions.empty)
            XCTAssertEqual(innerSubscriber.receive(1000), .none)
            innerSubscriber.receive(completion: .finished)

            XCTAssertEqual(subject.subscription.history, [.requested(.max(42)),
                                                          .requested(.max(43)),
                                                          .requested(.unlimited),
                                                          .requested(.max(44)),
                                                          .cancelled])
            XCTAssertEqual(subscriber.history, [.subscription("Multicast")])
        }
    }

    func testDeallocateConnectedMulticastBeforeCancelling() {
        // https://github.com/OpenCombine/OpenCombine/issues/186

        let publisher = CustomPublisher(subscription: CustomSubscription())
        var subjectDestroyed = false
        var subject: TrackingSubject<Int>? = .init(onDeinit: { subjectDestroyed = true })

        let connection = publisher.multicast(subject: subject!).connect()
        subject = nil
        XCTAssertTrue(subjectDestroyed)
        connection.cancel() // Shouldn't recursively aquire a non-recursive lock here.
    }

    func testLazySubjectCreation() {
        let publisher = PassthroughSubject<Int, TestingError>()
        var counter = 0
        let multicast = publisher
            .multicast { () -> PassthroughSubject<Int, TestingError> in
                counter += 1
                return .init()
            }

        multicast.subscribe(TrackingSubscriber())
        multicast.subscribe(TrackingSubscriber())
        multicast.subscribe(TrackingSubscriber())

        XCTAssertEqual(counter, 1, "The createSubject closure should be called once")

        _ = multicast.connect()

        XCTAssertEqual(counter, 1, "The createSubject closure should be called once")
    }

    func testMulticastReceiveSubscriptionTwice() {
        let publisher = CustomPublisher(subscription: CustomSubscription())
        var inner: AnySubscriber<Int, TestingError>?
        let trackingSubject = TrackingSubject<Int>(receiveSubscriber: { inner = $0 })
        let multicast = publisher.multicast(subject: trackingSubject)
        let tracking = TrackingSubscriber()
        multicast.subscribe(tracking)
        XCTAssertNotNil(inner)
        let extraSubscription = CustomSubscription()
        inner?.receive(subscription: extraSubscription)
        XCTAssertEqual(extraSubscription.history, [.cancelled])
    }

    func testMulticastReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([.subscription("Multicast")], demand: .none),
            { $0.multicast(PassthroughSubject.init) }
        )
    }

    func testMulticastReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("Multicast")]),
            { $0.multicast(PassthroughSubject.init) }
        )
    }

    func testReflection() throws {
        try MulticastTests.testGenericMulticastReflection {
            $0.multicast(PassthroughSubject.init)
        }
    }

    // MARK: - Generic tests for Multicast & MakeConnectable

    static func testGenericMulticast<Multicast: ConnectablePublisher>(
        _ makeMulticast: (CustomPublisherBase<Int, Never>) -> Multicast
    ) throws where Multicast.Output == Int, Multicast.Failure == Never {

        let publisher =
            CustomPublisherBase<Int, Never>(subscription: CustomSubscription())
        let multicast = makeMulticast(publisher)
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        multicast.subscribe(tracking)

        XCTAssertEqual(publisher.send(0), .none)
        XCTAssertEqual(publisher.send(12), .none)

        XCTAssertEqual(tracking.history, [.subscription("Multicast")])

        var connection = multicast.connect()

        XCTAssertEqual(publisher.send(-1), .none)
        XCTAssertEqual(publisher.send(42), .none)

        connection.cancel()

        XCTAssertEqual(publisher.send(14), .none)

        connection = multicast.connect()

        XCTAssertEqual(publisher.send(15), .none)
        publisher.send(completion: .finished)
        publisher.send(completion: .finished)

        connection.cancel()

        XCTAssertEqual(tracking.history, [.subscription("Multicast"),
                                          .value(-1),
                                          .value(42),
                                          .value(15),
                                          .completion(.finished)])
    }

    static func testGenericMulticastConnectTwice<Multicast: ConnectablePublisher>(
        _ makeMulticast: (TrackingSubjectBase<Int, Never>) -> Multicast
    ) where Multicast.Output == Int, Multicast.Failure == Never {
        let publisher = TrackingSubjectBase<Int, Never>()
        let multicast = makeMulticast(publisher)
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(10)) }
        )

        multicast.subscribe(tracking)

        publisher.send(-1)

        let connection1 = multicast.connect()
        let connection2 = multicast.connect()

        publisher.send(42)
        publisher.send(completion: .finished)

        withExtendedLifetime(multicast) {
            XCTAssertEqual(tracking.history, [.subscription("Multicast"),
                                              .value(42),
                                              .value(42),
                                              .completion(.finished)])
        }

        connection1.cancel()
        connection2.cancel()
    }

    static func testGenericMulticastDisconnect<Multicast: ConnectablePublisher>(
        _ makeMulticast: (PassthroughSubject<Int, Never>) -> Multicast
    ) where Multicast.Output == Int, Multicast.Failure == Never {

        let publisher = PassthroughSubject<Int, Never>()
        let multicast = makeMulticast(publisher)
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        multicast.subscribe(tracking)

        publisher.send(-1)

        var connection = multicast.connect()

        publisher.send(42)
        connection.cancel()
        publisher.send(100)

        multicast.subscribe(tracking)
        connection = multicast.connect()
        publisher.send(2)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.subscription("Multicast"),
                                          .value(42),
                                          .subscription("Multicast"),
                                          .value(2),
                                          .value(2),
                                          .completion(.finished),
                                          .completion(.finished)])

        connection.cancel()
    }

    static func testGenericMulticastReflection<Multicast: ConnectablePublisher>(
        _ makeMulticast: (PassthroughSubject<Int, Never>) -> Multicast
    ) throws where Multicast.Output == Int, Multicast.Failure == Never {

        let publisher = PassthroughSubject<Int, Never>()
        let multicast = makeMulticast(publisher)
        let tracking = TrackingSubscriberBase<Int, Never>()

        multicast.subscribe(tracking)

        let multicastSubscription =
            try XCTUnwrap(tracking.subscriptions.first?.underlying)

        let mirror =
            try XCTUnwrap((multicastSubscription as? CustomReflectable)?.customMirror)

        XCTAssert(mirror.children.isEmpty)

        let playgroundDescription =
            (multicastSubscription as? CustomPlaygroundDisplayConvertible)?
                .playgroundDescription as? String

        XCTAssertEqual(playgroundDescription, "Multicast")
    }
}

@available(macOS 10.15, iOS 13.0, *)
private final class MulticastTestingSubject: Subject {

    typealias Output = Int

    typealias Failure = TestingError

    let subscription = CustomSubscription()

    var subscriber: AnySubscriber<Int, TestingError>?

    func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Failure == TestingError, Downstream.Input == Int
    {
        subscriber.receive(subscription: subscription)
        self.subscriber = AnySubscriber(subscriber)
    }

    func send(subscription: Subscription) {
        subscriber?.receive(subscription: subscription)
    }

    func send(_ value: Int) {
        _ = subscriber?.receive(value)
    }

    func send(completion: Subscribers.Completion<TestingError>) {
        subscriber?.receive(completion: completion)
    }
}
