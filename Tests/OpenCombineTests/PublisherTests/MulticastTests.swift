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

        let publisher = CustomPublisher(subscription: CustomSubscription())
        let multicast = publisher.multicast(PassthroughSubject.init)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

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

    func testMulticastConnectTwice() {

        let publisher = TrackingSubject<Int>()
        let multicastSubject = TrackingSubject<Int>()
        let multicast = publisher.multicast(subject: multicastSubject)
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(10)) }
        )

        multicast.subscribe(tracking)

        publisher.send(-1)

        let connection1 = multicast.connect()
        let connection2 = multicast.connect()

        publisher.send(42)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.subscription("Multicast"),
                                          .value(42),
                                          .value(42),
                                          .completion(.finished)])

        connection1.cancel()
        connection2.cancel()
    }

    func testMulticastDisconnect() {

        let publisher = PassthroughSubject<Int, TestingError>()
        let multicast = publisher.multicast(PassthroughSubject.init)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

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
    }

    func testSubscribeAfterCompletion() {

        final class Subj: Subject {

            typealias Output = Int

            typealias Failure = TestingError

            var subscriber: AnySubscriber<Int, TestingError>?

            func receive<Downstream: Subscriber>(subscriber: Downstream)
                where Downstream.Failure == TestingError, Downstream.Input == Int
            {
                subscriber.receive(subscription: CustomSubscription())
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

        let publisher = CustomPublisher(subscription: CustomSubscription())

        let subject = Subj()

        let multicast = publisher.multicast(subject: subject)

        _ = multicast.connect()

        publisher.send(completion: .finished)

        let lateSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )

        multicast.subscribe(lateSubscriber)

        XCTAssertEqual(lateSubscriber.history, [.subscription("Multicast")])
    }
}
