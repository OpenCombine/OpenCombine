//
//  FlatMapTests.swift
//
//  Created by Eric Patey on 17.08.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class FlatMapTests: XCTestCase {

    func testFlatMapSequencesWithSink() {
        var history = [Int]()
        let cancellable = Publishers.Sequence<Range<Int>, Never>(sequence: 1 ..< 5)
            .flatMap { i in
                Publishers.Sequence(sequence: i ..< i + 4)
            }.sink {
                history.append($0)
            }

        XCTAssertEqual(history, [1, 2, 3, 4, 2, 3, 4, 5, 3, 4, 5, 6, 4, 5, 6, 7])

        cancellable.cancel()
    }

    func testFlatMapOneByOne() {
        let sequence = Publishers.Sequence<Range<Int>, Never>(sequence: 1 ..< 5)
            .flatMap(maxPublishers: .max(2)) { i in
                Publishers.Sequence(sequence: i ..< i + 4)
            }

        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: { _ in .max(1) }
        )
        sequence.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("FlatMap"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .value(5),
                                          .value(3),
                                          .value(4),
                                          .value(5),
                                          .value(6),
                                          .value(4),
                                          .value(5),
                                          .value(6),
                                          .value(7),
                                          .completion(.finished)])
    }

    func testSendsSubscriptionDownstreamBeforeSubscribingToUpstream() {
        let subscription = CustomSubscription()
        let upstream = CustomPublisher(subscription: subscription)
        let flatMap = upstream.flatMap(maxPublishers: .none) { _ in
            CustomPublisher(subscription: nil)
        }
        var downstreamReceivedSubscription = false
        var upstreamReceivedSubscriber = false
        let tracking = TrackingSubscriber(
            receiveSubscription: { _ in
                downstreamReceivedSubscription = true
                XCTAssertNil(upstream.erasedSubscriber)
            }
        )
        upstream.willSubscribe = { _, _ in
            upstreamReceivedSubscriber = true
            XCTAssertEqual(tracking.history, [.subscription("FlatMap")])
        }
        flatMap.subscribe(tracking)
        XCTAssert(downstreamReceivedSubscription)
        XCTAssert(upstreamReceivedSubscriber)
        XCTAssertEqual(subscription.history, [.requested(.none)])
    }

    func testSendsChildValues() {
        let upstreamPublisher = PassthroughSubject<
            PassthroughSubject<Int, TestingError>,
            TestingError>()
        let childPublisher1 = PassthroughSubject<Int, TestingError>()
        let childPublisher2 = PassthroughSubject<Int, TestingError>()

        let flatMap = upstreamPublisher.flatMap { $0 }

        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
        })

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send(childPublisher1)
        upstreamPublisher.send(childPublisher2)

        childPublisher1.send(666)
        childPublisher2.send(777)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .value(777)])
    }

    // This test ensures that the code can properly re-enter when synchronously receiving
    // a value during subscription (which Just(_) does).
    //  1. FlatMap.Inner.receive(_ input:)
    //    2. Publisher.subscribe
    //      ...
    //      3. FlatMap.Inner.ChildSubscriber.receive(subscription:)
    //        4. subscription.request()
    //          5. Just.Inner.request()
    //            6. FlatMap.Inner.child(_:receivedValue)
    //              7. lock
    //
    // At one point, I had a bug where the lock was taken by #1 before calling #2
    // This broke the rules of calling out with a lock held, and lead to a deadlock
    // at #7.
    //
    // Also, in my opinion, working around the issue with recursive locks is a smell.
    func testChildSubscribeDeadlock() {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisherBase<Int, Never>(
            subscription: upstreamSubscription)

        let flatMap = upstreamPublisher.flatMap(maxPublishers: .max(2)) { Just($0) }

        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) })

        flatMap.subscribe(downstreamSubscriber)
        XCTAssertEqual(upstreamPublisher.send(666), .none)

        // Simply making it here shows that there's no deadlock
    }

    func testCancelCancels() throws {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisherBase<Int, Never>(
            subscription: upstreamSubscription
        )

        let childSubscription = CustomSubscription()
        let childPublisher = CustomPublisherBase<Int, Never>(
            subscription: childSubscription
        )

        let flatMap = upstreamPublisher.flatMap { _ in childPublisher }

        var downstreamSubscription: Subscription?
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                downstreamSubscription = $0
                $0.request(.max(42))
            }
        )

        upstreamSubscription.onCancel = {
            XCTAssertEqual(childSubscription.history, [.requested(.max(1)), .cancelled])
        }

        childSubscription.onCancel = {
            XCTAssertEqual(upstreamSubscription.history, [.requested(.unlimited)])
        }

        flatMap.subscribe(downstreamSubscriber)

        XCTAssertEqual(upstreamPublisher.send(1), .none)

        try XCTUnwrap(downstreamSubscription).cancel()

        XCTAssertEqual(upstreamSubscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(childSubscription.history, [.requested(.max(1)), .cancelled])
    }

    func testCancelTwice() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(10),
            receiveValueDemand: .max(3),
            createSut: { $0.flatMap { $0 } })

        let childSubscription = CustomSubscription()
        XCTAssertEqual(
            helper.publisher.send(CustomPublisher(subscription: childSubscription)),
            .none
        )
        XCTAssertEqual(
            helper.publisher.send(CustomPublisher(subscription: childSubscription)),
            .none
        )
        XCTAssertEqual(
            helper.publisher.send(CustomPublisher(subscription: childSubscription)),
            .none
        )

        XCTAssertEqual(childSubscription.history, [.requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1))])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        XCTAssertEqual(childSubscription.history, [.requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .cancelled,
                                                   .cancelled,
                                                   .cancelled])
    }

    func testCrashesWhenRequestedZeroDemand() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.flatMap { _ in CustomPublisher(subscription: nil) } }
        )

        assertCrashes {
            helper.downstreamSubscription?.request(.none)
        }
    }

    func testUpstreamDemandWithMaxPublishers() {
        var upstreamDemand = Subscribers.Demand.none
        let upstreamSubscription = CustomSubscription(onRequest: { upstreamDemand += $0 })
        let upstreamPublisher = CustomPublisherBase<Int, Never>(
            subscription: upstreamSubscription)

        let flatMap = upstreamPublisher.flatMap(maxPublishers: .max(2)) { Just($0) }

        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) })

        flatMap.subscribe(downstreamSubscriber)

        XCTAssertEqual(upstreamDemand, .max(2))
    }

    func testUpstreamDemandWithNoMaxPublishers() {
        var upstreamDemand = Subscribers.Demand.none
        let upstreamSubscription = CustomSubscription(onRequest: { upstreamDemand += $0 })
        let upstreamPublisher = CustomPublisherBase<Int, Never>(
            subscription: upstreamSubscription)

        let flatMap = upstreamPublisher.flatMap { Just($0) }

        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) })

        flatMap.subscribe(downstreamSubscriber)

        XCTAssertEqual(upstreamDemand, .unlimited)
    }

    func testChildDemandWhenUnlimited() throws {
        let upstreamPublisher = PassthroughSubject<Void, Never>()

        var childDemand = Subscribers.Demand.none
        let childSubscription = CustomSubscription(onRequest: { childDemand += $0 })
        let childPublisher = CustomPublisherBase<Int, Never>(
            subscription: childSubscription)

        let flatMap = upstreamPublisher.flatMap { _ in childPublisher }

        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(receiveSubscription:
        {
            $0.request(.unlimited)
        })

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send()

        XCTAssertEqual(childDemand, .unlimited)

        XCTAssertEqual(childPublisher.send(666), .none)
    }

    func testChildDemandWhenLimited() throws {
        let upstreamPublisher = PassthroughSubject<AnyPublisher<Int, Never>, Never>()

        var child1Demand = Subscribers.Demand.none
        let child1Subscription = CustomSubscription(onRequest: {
            child1Demand += $0
        })
        let child1Publisher = CustomPublisherBase<Int, Never>(
            subscription: child1Subscription)

        var child2Demand = Subscribers.Demand.none
        let child2Subscription = CustomSubscription(onRequest: { child2Demand += $0 })
        let child2Publisher = CustomPublisherBase<Int, Never>(
            subscription: child2Subscription)

        let flatMap = upstreamPublisher.flatMap { $0 }

        var downstreamSubscription: Subscription?
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(receiveSubscription:
        {
            downstreamSubscription = $0
            $0.request(.max(2))
        })

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send(AnyPublisher(child1Publisher))
        upstreamPublisher.send(AnyPublisher(child2Publisher))

        // Apple starts out the children with a demand of 1. On receipt of a child value,
        // 1 more is demanded until it has one extra/buffered value after the downstream
        // demand is satisfied.
        XCTAssertEqual(child1Demand, .max(1))
        XCTAssertEqual(child2Demand, .max(1))

        // Downstream demand is 2, so:
        //  - this value gets sent
        //  - downstream demand goes down to 1
        //  - child is asked for 1 more
        XCTAssertEqual(child1Publisher.send(666), .max(1))
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666)])

        // Downstream demand is 1, so:
        //  - this value gets sent
        //  - downstream demand goes down to 0, but still need a buffered value
        //  - child is asked for 1 more
        XCTAssertEqual(child1Publisher.send(777), .max(1))
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .value(777)])

        // Downstream demand is 0, so:
        //  - this value is buffered and NOT sent
        //  - downstream demand is 0 and there's a buffered value
        //  - child is asked for 0 more
        XCTAssertEqual(child1Publisher.send(888), .none)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .value(777)])

        XCTAssertEqual(child1Publisher.send(999), .none)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .value(777)])

        // Downstream demands more, so:
        //  - the buffered value gets sent
        //  - child is asked for 1 more
        XCTAssertEqual(child1Demand, .max(1))
        XCTAssertEqual(child2Demand, .max(1))
        try XCTUnwrap(downstreamSubscription).request(.max(10))
        // This is a little odd, but rather than re-establishing a demand of 1 on the
        // child like it did initially, Apple appears to demand 1 of the child for every
        // buffered value that was sent. In this case, child1 is asked for 2 more.
        XCTAssertEqual(child1Demand, .max(3))
        XCTAssertEqual(child2Demand, .max(1))
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .value(777),
                                                      .value(888),
                                                      .value(999)])
    }

    func testDemandFromLimitedToUnlimited() {
        let upstreamPublisher = PassthroughSubject<Void, Never>()

        var childDemand = Subscribers.Demand.none
        let childSubscription = CustomSubscription(onRequest: { childDemand += $0 })
        let childPublisher = CustomPublisherBase<Int, Never>(
            subscription: childSubscription)

        let flatMap = upstreamPublisher.flatMap { _ in childPublisher }

        var downstreamSubscription: Subscription?
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(receiveSubscription:
        {
            downstreamSubscription = $0
            $0.request(.max(3))
        })

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send()

        XCTAssertEqual(childDemand, .max(1))

        downstreamSubscription?.request(.unlimited)
        XCTAssertEqual(childDemand, .unlimited)
    }

    func testChildValueReceivedWhileSendingValue() throws {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisherBase<CustomPublisher, TestingError>(
            subscription: upstreamSubscription
        )

        let childSubscription1 = CustomSubscription()
        let childSubscription2 = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: childSubscription1)
        let child2Publisher = CustomPublisher(subscription: childSubscription2)

        let flatMap = upstreamPublisher.flatMap { $0 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(2)) },
            receiveValue: { _ in
                _ = child2Publisher.send(777)
                return .none
            }
        )

        flatMap.subscribe(downstreamSubscriber)

        XCTAssertEqual(upstreamPublisher.send(child1Publisher), .none)
        XCTAssertEqual(upstreamPublisher.send(child2Publisher), .none)

        XCTAssertEqual(child1Publisher.send(666), .max(1))

        XCTAssertEqual(upstreamSubscription.history, [.requested(.unlimited)])
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .value(777)])
        XCTAssertEqual(childSubscription1.history, [.requested(.max(1))])
        XCTAssertEqual(childSubscription2.history, [.requested(.max(1))])
    }

    func testOuterLockReentrance() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.flatMap(maxPublishers: .max(1)) { $0 } }
        )

        let childSubscription = CustomSubscription()
        let child = CustomPublisher(subscription: childSubscription)

        var recursionDepth = 5
        helper.subscription.onRequest = { _ in
            if recursionDepth <= 0 {
                return
            }
            recursionDepth -= 1
            child.send(completion: .finished)
        }

        XCTAssertEqual(helper.publisher.send(child), .none)

        child.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1))])
        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])
    }

    func testDownstreamLockReentrance() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.flatMap(maxPublishers: .max(1)) { $0 } }
        )

        let childSubscription = CustomSubscription()
        let child = CustomPublisher(subscription: childSubscription)

        XCTAssertEqual(helper.publisher.send(child), .none)

        // Create some downstream demand
        try XCTUnwrap(helper.downstreamSubscription).request(.max(5))

        var recursionDepth = 10
        helper.tracking.onFailure = { _ in
            if recursionDepth <= 0 {
                return
            }
            recursionDepth -= 1
            _ = child.send(1)
        }

        child.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .completion(.failure(.oops)),
                                                 .value(1)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])
    }

    func testCompletesProperlyWhenUpstreamOutlivesChildren() {
        let upstreamPublisher = PassthroughSubject<AnyPublisher<Int, Never>, Never>()
        let child1 = PassthroughSubject<Int, Never>()
        let child2 = PassthroughSubject<Int, Never>()
        let flatMap = upstreamPublisher.flatMap { $0 }
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) })

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send(AnyPublisher(child1))
        upstreamPublisher.send(AnyPublisher(child2))

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap")])

        child1.send(666)
        child1.send(completion: .finished)

        // Better stay alive even after upstream and one child finished
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                          .value(666)])

        child2.send(777)
        child2.send(completion: .finished)

        // Better stay alive even after all children finished
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                          .value(666),
                                          .value(777)])

        upstreamPublisher.send(completion: .finished)

        // Better complete when upstream and all children finished
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                          .value(666),
                                          .value(777),
                                          .completion(.finished)])
    }

    func testDownstreamFinishesWhenUpstreamAndChildFinishes() {
        let childSubscription = CustomSubscription()
        let child = CustomPublisher(subscription: childSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.flatMap(maxPublishers: .max(1)) { $0 } }
        )

        XCTAssertEqual(helper.publisher.send(child), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap")])

        child.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .completion(.finished)])

        child.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])
    }

    func testUpstreamFinishesWhenThereArePendingChildSubscriptions() {
        let childSubscription = CustomSubscription()
        let child = CustomPublisher(subscription: childSubscription)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.flatMap(maxPublishers: .max(1)) { $0 } }
        )

        child.willSubscribe = { subscriber, _ in
            helper.publisher.send(completion: .finished)
        }

        XCTAssertEqual(helper.publisher.send(child), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])
        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap")])
    }

    func testCompletesProperlyWhenChildrenOutliveUpstream() {
        let childSubscription1 = CustomSubscription()
        let child1 = CustomPublisher(subscription: childSubscription1)
        let childSubscription2 = CustomSubscription()
        let child2 = CustomPublisher(subscription: childSubscription2)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: { $0.flatMap { $0 } }
        )

        XCTAssertEqual(helper.publisher.send(child1), .none)
        XCTAssertEqual(helper.publisher.send(child2), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap")])

        helper.publisher.send(completion: .finished)

        // Better stay alive even after upstream finished
        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap")])

        XCTAssertEqual(child1.send(666), .none)
        child1.send(completion: .finished)

        // Better stay alive even after upstream and one child finished
        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .value(666)])

        XCTAssertEqual(child1.send(777), .none)
        child2.send(completion: .finished)

        // Better complete when upstream and all children finished
        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .value(666),
                                                 .value(777),
                                                 .completion(.finished)])

        XCTAssertEqual(childSubscription1.history, [.requested(.unlimited)])
        XCTAssertEqual(childSubscription2.history, [.requested(.unlimited)])
    }

    func testCrashesWhenUpstreamFailsDuringChildCancellation() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: { $0.flatMap { $0 } }
        )

        let childSubscription = CustomSubscription()
        let child = CustomPublisher(subscription: childSubscription)

        var counter = 0
        childSubscription.onCancel = {
            if counter >= 5 { return }
            counter += 1
            helper.publisher.send(completion: .failure(.oops))
        }

        XCTAssertEqual(helper.publisher.send(child), .none)

        assertCrashes {
            helper.publisher.send(completion: .failure(.oops))
        }
    }

    func testDoesNotCompleteWithBufferedValues() {
        let upstreamPublisher = PassthroughSubject<Void, Never>()

        let childSubscription = CustomSubscription()
        let childPublisher = CustomPublisherBase<Int, Never>(
            subscription: childSubscription)

        let flatMap = upstreamPublisher.flatMap { _ in childPublisher }

        var downstreamSubscription: Subscription?
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(receiveSubscription:
        {
            downstreamSubscription = $0
            $0.request(.max(1))
        })

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send()

        XCTAssertEqual(childPublisher.send(666), .max(1))
        XCTAssertEqual(childPublisher.send(777), .none)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666)])

        upstreamPublisher.send(completion: .finished)
        childPublisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666)])

        downstreamSubscription?.request(.unlimited)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .value(777),
                                                      .completion(.finished)])
    }

    func testFailsIfUpstreamFails() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(4),
            receiveValueDemand: .max(2),
            createSut: { $0.flatMap(maxPublishers: .max(3)) { $0 } }
        )

        let childSubscription = CustomSubscription()
        let child1 = CustomPublisher(subscription: childSubscription)

        helper.tracking.onFailure = { _ in
            XCTAssertEqual(
                childSubscription.history,
                [.requested(.max(1)), .cancelled],
                """
                Failure should be sent downstream after the child subscriptions were \
                cancelled
                """)
        }

        XCTAssertEqual(helper.publisher.send(child1), .none)

        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])

        helper.publisher.send(completion: .failure(TestingError.oops))
        helper.publisher.send(completion: .failure(TestingError.oops))

        let child2 = CustomPublisher(subscription: nil)
        XCTAssertEqual(helper.publisher.send(child2), .none)

        XCTAssertEqual(childSubscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertNil(child2.erasedSubscriber)
    }

    func testFailsIfChildFails() {
        let childSubscription1 = CustomSubscription()
        let child1 = CustomPublisher(subscription: childSubscription1)
        let childSubscription2 = CustomSubscription()
        let child2 = CustomPublisher(subscription: childSubscription2)
        let childSubscription3 = CustomSubscription()
        let child3 = CustomPublisher(subscription: childSubscription3)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: { $0.flatMap { $0 } }
        )
        XCTAssertEqual(helper.publisher.send(child1), .none)
        XCTAssertEqual(helper.publisher.send(child2), .none)
        XCTAssertEqual(helper.publisher.send(child3), .none)

        child2.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(childSubscription1.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(childSubscription2.history, [.requested(.unlimited)])
        XCTAssertEqual(childSubscription3.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .completion(.failure(.oops))])

        child3.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(childSubscription1.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(childSubscription2.history, [.requested(.unlimited)])
        XCTAssertEqual(childSubscription3.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("FlatMap"),
                        .completion(.failure(TestingError.oops))])
    }

    func testFailsWithoutSendingBufferedValues() {
        let upstreamPublisher = PassthroughSubject<
            PassthroughSubject<Int, TestingError>,
            TestingError>()
        let childPublisher = PassthroughSubject<Int, TestingError>()

        let flatMap = upstreamPublisher.flatMap { $0 }

        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            $0.request(.max(1))
        })

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send(childPublisher)

        // Send a value
        childPublisher.send(666)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666)])

        // Buffer a value
        childPublisher.send(777)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666)])

        // Fail
        let error = TestingError.oops
        upstreamPublisher.send(completion: .failure(error))
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .completion(.failure(error))])
    }

    func testAllSubscriptionsReleasedOnUpstreamFailure() {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisherBase<Int, TestingError>(
            subscription: upstreamSubscription)
        let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) })

        let childSubscription = CustomSubscription()
        let child = CustomPublisher(subscription: childSubscription)

        let flatMap = upstreamPublisher.flatMap { _ in child }

        flatMap.subscribe(downstreamSubscriber)

        XCTAssertEqual(upstreamPublisher.send(1), .none)
        XCTAssertEqual(child.send(666), .none)
        upstreamPublisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(childSubscription.history, [.requested(.unlimited),
                                                   .cancelled])
        XCTAssertEqual(upstreamSubscription.history, [.requested(.unlimited)])
    }

    func testAllSubscriptionsReleasedOnChildFailure() {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisherBase<Int, TestingError>(
            subscription: upstreamSubscription)
        let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) })

        let child1 = PassthroughSubject<Int, TestingError>()
        let child2Subscription = CustomSubscription()
        let child2 = CustomPublisher(subscription: child2Subscription)

        let children = [AnyPublisher(child1), AnyPublisher(child2)]
        let flatMap = upstreamPublisher.flatMap { children[$0] }

        flatMap.subscribe(downstreamSubscriber)

        XCTAssertEqual(upstreamPublisher.send(0), .none)
        XCTAssertEqual(upstreamPublisher.send(1), .none)
        child1.send(666)
        XCTAssertEqual(child2.send(777), .none)
        child1.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(child2Subscription.history, [.requested(.unlimited),
                                                    .cancelled])
        XCTAssertEqual(upstreamSubscription.history, [.requested(.unlimited)])
    }

    func testRecursiveRequest() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.flatMap(maxPublishers: .max(1)) { $0 } }
        )

        helper.tracking.onValue = { value in
            // This shouldn't recurse
            if value == 0 {
                helper.downstreamSubscription?.request(.max(3))
            }
        }

        let childSubscription = CustomSubscription()
        let child = CustomPublisher(subscription: childSubscription)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        XCTAssertEqual(helper.publisher.send(child), .none)

        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])

        XCTAssertEqual(child.send(0), .max(1))
        XCTAssertEqual(child.send(1), .max(1))
        XCTAssertEqual(child.send(2), .max(1))
        XCTAssertEqual(child.send(3), .max(1))
        XCTAssertEqual(child.send(4), .none)
        XCTAssertEqual(child.send(5), .none)
        XCTAssertEqual(child.send(6), .none)

        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .value(0),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(10))

        XCTAssertEqual(childSubscription.history, [.requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])
        XCTAssertEqual(helper.tracking.history, [.subscription("FlatMap"),
                                                 .value(0),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4),
                                                 .value(5),
                                                 .value(6)])
    }

    func testSendsValuesUntilBufferIsEmpty() throws {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisherBase<CustomPublisher, TestingError>(
            subscription: upstreamSubscription
        )
        var downstreamSubscription: Subscription?
        let flatMap = upstreamPublisher.flatMap { $0 }
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                downstreamSubscription = $0
            },
            receiveValue: {
                if $0 > 0 {
                    return .max($0)
                }
                return .none
            }
        )
        flatMap.subscribe(tracking)
        XCTAssertEqual(upstreamSubscription.history, [.requested(.unlimited)])
        let childSubscription = CustomSubscription()
        let childPublisher = CustomPublisher(subscription: childSubscription)
        XCTAssertEqual(upstreamPublisher.send(childPublisher), .none)
        XCTAssertEqual(childSubscription.history, [.requested(.max(1))])

        XCTAssertEqual(childPublisher.send(2), .none)
        XCTAssertEqual(tracking.history, [.subscription("FlatMap")])
        try XCTUnwrap(downstreamSubscription).request(.max(1))
        XCTAssertEqual(tracking.history, [.subscription("FlatMap"), .value(2)])
        XCTAssertEqual(childPublisher.send(1), .max(1))
        XCTAssertEqual(childPublisher.send(-1), .max(1))
        XCTAssertEqual(childPublisher.send(-2), .max(1))
        XCTAssertEqual(childPublisher.send(-3), .none)
        XCTAssertEqual(childPublisher.send(-4), .none)
        XCTAssertEqual(childPublisher.send(2), .none)
        XCTAssertEqual(childPublisher.send(-5), .none)
        XCTAssertEqual(childPublisher.send(-6), .none)
        XCTAssertEqual(childPublisher.send(-7), .none)

        XCTAssertEqual(tracking.history, [.subscription("FlatMap"),
                                          .value(2),
                                          .value(1),
                                          .value(-1),
                                          .value(-2)])

        childSubscription.onRequest = { _ in
            XCTAssertEqual(childPublisher.send(-42), .none)
        }

        try XCTUnwrap(downstreamSubscription).request(.max(3))
        XCTAssertEqual(tracking.history, [.subscription("FlatMap"),
                                          .value(2),
                                          .value(1),
                                          .value(-1),
                                          .value(-2),
                                          .value(-3),
                                          .value(-4),
                                          .value(2),
                                          .value(-5),
                                          .value(-6)])
        XCTAssertEqual(childSubscription.history, [.requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1)),
                                                   .requested(.max(1))])
    }

    func testSendsSubscriptionDownstreamBeforeDemandUpstream() {
        let sentDemandRequestUpstream = "Sent demand request upstream"
        let sentSubscriptionDownstream = "Sent subscription downstream"
        var receiveOrder: [String] = []

        let upstreamSubscription = CustomSubscription(onRequest: { _ in
            receiveOrder.append(sentDemandRequestUpstream) })
        let upstreamPublisher = CustomPublisherBase<Int, Never>(
            subscription: upstreamSubscription)
        let flatMapPublisher = upstreamPublisher.flatMap { Just($0) }
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { _ in receiveOrder.append(sentSubscriptionDownstream) })

        flatMapPublisher.subscribe(downstreamSubscriber)

        XCTAssertEqual(receiveOrder, [sentSubscriptionDownstream,
                                      sentDemandRequestUpstream])
    }

    func testFlatMapReceiveSubscriptionTwice() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Never>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.flatMap(ResultPublisher.init) }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled,
                                                     .cancelled])

        let thirdSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)

        XCTAssertEqual(thirdSubscription.history, [.cancelled])

        helper.publisher.send(completion: .finished)

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)

        XCTAssertEqual(thirdSubscription.history, [.cancelled, .cancelled])
    }

    func testFlatMapReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([.subscription("FlatMap")], demand: .none),
            { $0.flatMap { _ in Just(0) } }
        )
    }

    func testFlatMapReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("FlatMap"), .completion(.finished)]),
            { $0.flatMap { _ in Just(0) } }
        )
    }

    @available(macOS 11.0, iOS 14.0, *)
    func testOverloadWhenUpstreamNeverFailsButChildrenCanFail() {
        let child = CustomPublisher(subscription: nil)
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Never>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.flatMap { _ in child } }
        )

        XCTAssertEqual(helper.sut.upstream.upstream, helper.publisher)
        XCTAssertEqual(helper.sut.transform(0), child)
    }

    @available(macOS 11.0, iOS 14.0, *)
    func testOverloadWhenUpstreamCanFailButChildrenNeverFail() {
        let child = CustomPublisherBase<Int, Never>(subscription: nil)

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int,
                                               TestingError>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.flatMap { _ in child } }
        )

        XCTAssertEqual(helper.sut.upstream, helper.publisher)
        XCTAssertEqual(helper.sut.transform(0).upstream, child)
    }

    func testFlatMapReflection() throws {
        try testReflection(parentInput: String.self,
                           parentFailure: Never.self,
                           description: "FlatMap",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "FlatMap",
                           { $0.flatMap { Just($0) } })

        let innerPublisher = CustomPublisher(subscription: CustomSubscription())
        let outerPublisher = CustomPublisher(subscription: CustomSubscription())
        let flatMap = outerPublisher.flatMap { _ in innerPublisher }
        let tracking = TrackingSubscriber()
        flatMap.subscribe(tracking)
        XCTAssertEqual(outerPublisher.send(0), .none)

        let innerSubscriber = try XCTUnwrap(innerPublisher.erasedSubscriber)

        XCTAssertEqual((innerSubscriber as? CustomStringConvertible)?.description,
                       "FlatMap")

        let customMirror =
            try XCTUnwrap((innerSubscriber as? CustomReflectable)?.customMirror)

        let outerSubscriberCombineIdentifier = try XCTUnwrap(
            (outerPublisher.erasedSubscriber as? CustomCombineIdentifierConvertible)?
                .combineIdentifier
        )
        expectedChildren(
            ("parentSubscription",
             .matches("\(outerSubscriberCombineIdentifier)"))
        )(customMirror)

        XCTAssertFalse(innerSubscriber is CustomDebugStringConvertible,
                       "subscriber shouldn't conform to CustomDebugStringConvertible")

        XCTAssertEqual(
            ((innerSubscriber as? CustomPlaygroundDisplayConvertible)?
                .playgroundDescription as? String),
            "FlatMap"
        )
    }
}
