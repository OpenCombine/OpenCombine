//
//  ShareTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 03/10/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ShareTests: XCTestCase {

    func testBasicBehavior() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let share = publisher.share()

        XCTAssertEqual(subscription.history, [])

        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(42)) },
            receiveValue: { .max($0) }
        )

        share.subscribe(tracking)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("Multicast")])

        XCTAssertEqual(publisher.send(1), .none)
        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(publisher.send(3), .none)
        publisher.send(completion: .failure(.oops))

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("Multicast"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .completion(.failure(.oops))])
    }

    func testLateSubscriber() {
        let subscription = CustomSubscription()

        let publisher = CustomPublisher(subscription: subscription)
        let share = publisher.share()

        let earlySubscriber = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(3))
            }
        )

        share.subscribe(earlySubscriber)

        XCTAssertNotNil(publisher.subscriber)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(earlySubscriber.history, [.subscription("Multicast")])

        XCTAssertEqual(publisher.send(1), .none)
        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(publisher.send(3), .none)
        XCTAssertEqual(publisher.send(4), .none)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(earlySubscriber.history, [.subscription("Multicast"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3)])

        let lateSubscriber = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(2))
            }
        )

        share.subscribe(lateSubscriber)

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

        publisher.send(completion: .finished)

        let latestSubscriber = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.none)
            }
        )

        share.subscribe(latestSubscriber)

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
    }

    func testEquatable() {

        let publisher = CustomPublisher(subscription: nil)
        let share1 = publisher.share()
        let share2 = publisher.share()

        XCTAssertEqual(share1, share1)
        XCTAssertEqual(share2, share2)
        XCTAssertNotEqual(share1, share2)
        XCTAssertNotEqual(share2, share1)
    }

    func testShareReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([.subscription("Multicast")], demand: .none),
            { $0.share() }
        )
    }

    func testShareCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("Multicast")]),
            { $0.share() }
        )
    }
}
