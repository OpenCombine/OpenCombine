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
        ("testOperatorSpecializations", testOperatorSpecializations),
    ]

    private typealias Sut = Publishers.Just

    func testJustNoInitialDemand() {
        let just = Sut(42)
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
        let just = Sut(42)
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

    func testOperatorSpecializations() {

        XCTAssertEqual(Sut(112).min(), Sut(112))
        XCTAssertEqual(Sut(341).max(), Sut(341))

        XCTAssertEqual(Sut(10).contains(12), Sut(false))
        XCTAssertEqual(Sut(10).contains(10), Sut(true))

        XCTAssertEqual(Sut(1000).removeDuplicates(), Sut(1000))

        XCTAssertEqual(Sut(0).allSatisfy { $0 > 0 }, Sut(false))
        XCTAssertEqual(Sut(1).allSatisfy { $0 > 0 }, Sut(true))

        XCTAssertEqual(Sut(64).contains { $0 < 100 }, Sut(true))
        XCTAssertEqual(Sut(14).contains { $0 > 100 }, Sut(false))

        XCTAssertEqual(Sut(13).collect(), Sut([13]))

        XCTAssertEqual(Sut(1).min(by: >), Sut(1))
        XCTAssertEqual(Sut(2).max(by: >), Sut(2))

        XCTAssertEqual(Sut(10000).count(), Sut(1))

        XCTAssertEqual(Sut("f").first(), Sut("f"))
        XCTAssertEqual(Sut("g").last(), Sut("g"))

        XCTAssertTrue(Sut(13.0).ignoreOutput().completeImmediately)

        XCTAssertEqual(Sut(42).map(String.init), Sut("42"))

        XCTAssertEqual(Sut(44).removeDuplicates(by: <), Sut(44))

        XCTAssertEqual(Sut(1).replaceError(with: 100), Sut(1))
        XCTAssertEqual(Sut(1).replaceEmpty(with: 100), Sut(1))

        XCTAssertEqual(Sut(1).retry(), Sut(1))
        XCTAssertEqual(Sut(1).retry(100), Sut(1))
    }
}
