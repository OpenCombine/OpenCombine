//
//  JustTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class JustTests: XCTestCase {

    static let allTests = [
        ("testJustNoInitialDemand", testJustNoInitialDemand),
        ("testJustWithInitialDemand", testJustWithInitialDemand),
        ("testLifecycle", testLifecycle),
    ]

    func testJustNoInitialDemand() {
        let just = Publishers.Just(42)
        let tracking = TrackingSubscriberBase<Never>()
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty)])

        tracking.subscriptions.first?.request(.max(100))
        tracking.subscriptions.first?.request(.max(1))

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testJustWithInitialDemand() {
        let just = Publishers.Just(42)
        let tracking =
            TrackingSubscriberBase<Never>(receiveSubscription: { $0.request(.unlimited) })
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testLifecycle() {
        var deinitCount = 0
        do {
            let just = Publishers.Just(42)
            let tracking = TrackingSubscriberBase<Never>(onDeinit: { deinitCount += 1 })
            just.subscribe(tracking)
            tracking.subscriptions.first?.cancel()
        }
        XCTAssertEqual(deinitCount, 1)
    }
}
