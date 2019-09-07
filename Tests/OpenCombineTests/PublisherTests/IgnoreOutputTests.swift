//
//  IgnoreOutputTests.swift
//
//  Created by Eric Patey on 16.08.20019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class IgnoreOutputTests: XCTestCase {

    func testCompletionWithEmpty() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let ignoreOutputPublisher = publisher.ignoreOutput()
        let tracking = TrackingSubscriberBase<Never, TestingError>(
            receiveSubscription: { $0.request(.max(42)) }
        )

        XCTAssertEqual(tracking.history, [])

        ignoreOutputPublisher.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput"),
                                          .completion(.finished)])
    }

    func testCompletionWithValues() {
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisher(subscription: upstreamSubscription)
        let ignoreOutputPublisher = upstreamPublisher.ignoreOutput()
        let tracking = TrackingSubscriberBase<Never, TestingError>(
            receiveSubscription: { $0.request(.max(42)) }
        )

        XCTAssertEqual(tracking.history, [])

        ignoreOutputPublisher.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        XCTAssertEqual(upstreamPublisher.send(666), .none)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        upstreamPublisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput"),
                                          .completion(.finished)])
    }

    func testCompletionWithError() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let ignoreOutputPublisher = publisher.ignoreOutput()
        let tracking = TrackingSubscriberBase<Never, TestingError>(
            receiveSubscription: { $0.request(.max(42)) }
        )

        XCTAssertEqual(tracking.history, [])

        ignoreOutputPublisher.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        XCTAssertEqual(publisher.send(666), .none)
        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput")])

        publisher.send(completion: .failure(.oops))

        XCTAssertEqual(tracking.history, [.subscription("IgnoreOutput"),
                                          .completion(.failure(.oops))])
    }

    func testDemand() {
        // demand from downstream is ignored since no values are ever
        // sent. upstream demand is set to unlimited and left alone.
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let ignoreOutput = publisher.ignoreOutput()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Never, TestingError>(
            receiveSubscription: {
                $0.request(.max(42))
                downstreamSubscription = $0
            })

        ignoreOutput.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(0), .none)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(2), .none)
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

    func testSendsSubcriptionDownstreamBeforeDemandUpstream() {
        let sentDemandRequestUpstream = "Sent demand request upstream"
        let sentSubscriptionDownstream = "Sent subcription downstream"
        var receiveOrder: [String] = []

        let subscription = CustomSubscription(onRequest: { _ in
            receiveOrder.append(sentDemandRequestUpstream)
        })
        let publisher = CustomPublisher(subscription: subscription)
        let ignoreOutputPublisher = publisher.ignoreOutput()
        let tracking =
            TrackingSubscriberBase<Never, TestingError>(receiveSubscription: { _ in
                receiveOrder.append(sentSubscriptionDownstream)
            })

        ignoreOutputPublisher.subscribe(tracking)

        XCTAssertEqual(receiveOrder, [sentSubscriptionDownstream,
                                      sentDemandRequestUpstream])
    }
}
