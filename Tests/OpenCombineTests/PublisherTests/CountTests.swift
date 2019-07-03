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

@available(macOS 10.15, *)
final class CountTests: XCTestCase {

    static let allTests = [
        ("testSendsCorrectCount", testSendsCorrectCount),
        ("testCountWaitsUntilFinishedToSend", testCountWaitsUntilFinishedToSend)
    ]

    func testSendsCorrectCount() {
        var currentCount = 0

        let publisher = PassthroughSubject<Void, Never>()
        _ = publisher
            .count()
            .sink(receiveValue: { currentCount = $0 })

        let sendAmount = Int.random(in: 1...1000)
        for _ in 0..<sendAmount {
            publisher.send()
        }

        publisher.send(completion: .finished)
        XCTAssert(currentCount == sendAmount)
    }

    func testCountWaitsUntilFinishedToSend() {
        var currentCount = 0

        let publisher = PassthroughSubject<Void, Never>()
        _ = publisher
            .count()
            .sink(receiveValue: { currentCount = $0 })

        publisher.send()
        XCTAssert(currentCount == 0)

        publisher.send()
        XCTAssert(currentCount == 0)

        publisher.send(completion: .finished)
        XCTAssert(currentCount == 2)
    }

    func testDemand() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.count()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(42))
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(4) }
        )

        drop.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)
        dump(type(of: downstreamSubscription!))

        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        XCTAssertEqual(publisher.send(0), .max(42))
        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        XCTAssertEqual(publisher.send(2), .max(42))
        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        downstreamSubscription?.request(.max(95))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5))])

        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .cancelled])

        downstreamSubscription?.request(.max(50))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .cancelled])
    }
}
