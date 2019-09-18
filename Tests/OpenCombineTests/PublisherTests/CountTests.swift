//
//  CountTests.swift
//
//
//  Created by Joseph Spadafora on 6/25/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CountTests: XCTestCase {

    func testSendsCorrectCount() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let countPublisher = publisher.count()
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(42)) }
        )

        XCTAssertEqual(tracking.history, [])

        countPublisher.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("Count")])

        let sendAmount = Int.random(in: 1...1000)
        for _ in 0..<sendAmount {
            _ = publisher.send(3)
        }
        XCTAssertEqual(tracking.history, [.subscription("Count")])

        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("Count"),
                                          .value(sendAmount),
                                          .completion(.finished)])
    }

    func testCountWaitsUntilFinishedToSend() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let countPublisher = publisher.count()
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(42)) }
        )

        countPublisher.subscribe(tracking)

        _ = publisher.send(1)
        XCTAssertEqual(tracking.history, [.subscription("Count")])

        _ = publisher.send(2)
        XCTAssertEqual(tracking.history, [.subscription("Count")])

        _ = publisher.send(0)
        XCTAssertEqual(tracking.history, [.subscription("Count")])

        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("Count"),
                                          .value(3),
                                          .completion(.finished)])
    }

    func testDemand() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let countPublisher = publisher.count()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(42))
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(4) }
        )

        countPublisher.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(0), .max(0))
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(2), .max(0))
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        downstreamSubscription?.request(.max(95))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled])

        downstreamSubscription?.request(.max(50))
        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled])
    }

    func testAddingSubscriberRequestsUnlimitedDemand() {
        // When
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let countPublisher = publisher.count()
        let tracking = TrackingSubscriber()

        // Given
        XCTAssertEqual(subscription.history, [])
        countPublisher.subscribe(tracking)

        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }

    func testReceivesSubscriptionBeforeRequestingUpstream() {
        let upstreamRequest = "Requested upstream subscription"
        let receiveDownstream = "Receive downstream"
        var receiveOrder: [String] = []

        let subscription = CustomSubscription(onRequest: { _ in
            receiveOrder.append(upstreamRequest)
        })
        let publisher = CustomPublisher(subscription: subscription)
        let countPublisher = publisher.count()
        let tracking = TrackingSubscriber(receiveSubscription: { _ in
            receiveOrder.append(receiveDownstream)
        })

        countPublisher.subscribe(tracking)

        XCTAssertEqual(receiveOrder, [receiveDownstream, upstreamRequest])
    }
}
