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

/// Helper function for predictably testing concurrency/race scenarios.
/// - Parameter block: block to execute concurrently
///
/// Apple, surprisingly, calls out to subscribers with a lock held. This will absolutely
/// block children who send values concurrently until the current downstream value
/// delivery has been completed.
///
/// This means that, without a timeout, the code below is guaranteed to deadlock. Because
/// of this we need to choose a timeout that is low enough to not materially slow down the
/// tests, but long enough to ensure that we are effectively testing the desired race
/// conditions. It needs to be a long enough timeout to allow the caller's block to begin
/// executing.
///
/// I understand that timeouts like this are a smell. I'd be happy to entertain other ways
/// to deterministically test concurrency/race conditions.

private func performConcurrentBlock(_ block: @escaping () -> Void) {
    let sem = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .background).async {
        block()
        sem.signal()
    }
    #if OPENCOMBINE_COMPATIBILITY_TEST
    // If running in compatibility mode, assert that we got a timeout. If not, Apple
    // changed their implementation to not call out with a lock held.
    XCTAssertEqual(sem.wait(timeout: DispatchTime.now() + 0.01), .timedOut)
    #else
    sem.wait()
    #endif
}

@available(macOS 10.15, iOS 13.0, *)
final class FlatMapTests: XCTestCase {

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
    //      3. FlatMap.Inner.ChildSubscriber.recive(subscription:)
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

        // Simply making it here shows that there's no dealock
    }

    func testCancelCancels() {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisherBase<Int, Never>(
            subscription: upstreamSubscription)

        let childSubscription = CustomSubscription()
        let childPublisher = CustomPublisherBase<Int, Never>(
            subscription: childSubscription)

        let flatMap = upstreamPublisher.flatMap { _ in childPublisher }

        var downstreamSubscription: Subscription?
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(receiveSubscription:
        {
            downstreamSubscription = $0
            $0.request(.unlimited)
        })

        flatMap.subscribe(downstreamSubscriber)

        XCTAssertEqual(upstreamPublisher.send(1), .none)

        downstreamSubscription?.cancel()

        XCTAssertEqual(upstreamSubscription.history.last, .cancelled)
        XCTAssertEqual(childSubscription.history.last, .cancelled)
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
        let child1Subscription = CustomSubscription(onRequest: { child1Demand += $0 })
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
        let upstreamPublisher = PassthroughSubject<AnyPublisher<Int, TestingError>,
            TestingError>()

        let child1Publisher = CustomPublisher(subscription: CustomSubscription())
        let child2Publisher = CustomPublisher(subscription: CustomSubscription())

        let flatMap = upstreamPublisher.flatMap { $0 }

        let received777Sem = DispatchSemaphore(value: 0)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(2)) },
            receiveValue: {
                if $0 == 666 {
                    performConcurrentBlock {
                        XCTAssertEqual(child2Publisher.send(777), .max(1))
                    }
                } else if $0 == 777 {
                    received777Sem.signal()
                }
                return .none
            }
        )

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send(AnyPublisher(child1Publisher))
        upstreamPublisher.send(AnyPublisher(child2Publisher))

        XCTAssertEqual(child1Publisher.send(666), .max(1))
        received777Sem.wait()
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                                      .value(666),
                                                      .value(777)])
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

    func testCompletesProperlyWhenChildrenOutliveUpstream() {
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

        upstreamPublisher.send(completion: .finished)

        // Better stay alive even after upstream finished
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap")])

        child1.send(666)
        child1.send(completion: .finished)

        // Better stay alive even after upstream and one child finished
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                          .value(666)])

        child2.send(777)
        child2.send(completion: .finished)

        // Better complete when upstream and all children finished
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                          .value(666),
                                          .value(777),
                                          .completion(.finished)])
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
        let upstreamPublisher = PassthroughSubject<
            AnyPublisher<Int, TestingError>,
            TestingError>()
        let flatMap = upstreamPublisher.flatMap { $0 }
        let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) })

        flatMap.subscribe(downstreamSubscriber)

        upstreamPublisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("FlatMap"),
                                          .completion(.failure(TestingError.oops))])
    }

    func testFailsIfChildFails() {
        let upstream = PassthroughSubject<AnyPublisher<Int, TestingError>, TestingError>()
        let child = PassthroughSubject<Int, TestingError>()
        let flatMap = upstream.flatMap { $0 }
        let tracking = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) })

        flatMap.subscribe(tracking)
        upstream.send(AnyPublisher(child))

        child.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(tracking.history, [.subscription("FlatMap"),
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

    func testSendsSubcriptionDownstreamBeforeDemandUpstream() {
        let sentDemandRequestUpstream = "Sent demand request upstream"
        let sentSubscriptionDownstream = "Sent subcription downstream"
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
}
