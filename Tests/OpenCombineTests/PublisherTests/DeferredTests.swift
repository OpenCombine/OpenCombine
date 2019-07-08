//
//  DeferredTests.swift
//  
//
//  Created by Joseph Spadafora on 7/7/19.
//

import XCTest

//import Combine
#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class DeferredTests: XCTestCase {

    static let allTests = [
        ("testDeferredNotCalledBeforeSubscription",
            testDeferredNotCalledBeforeSubscription),
        ("testDeferredCreatedAfterSubscription",
            testDeferredCreatedAfterSubscription)
    ]

    func testDeferredNotCalledBeforeSubscription() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        _ = Publishers.Deferred {
            publisher
        }

        XCTAssertEqual(subscription.history, [])
    }

    func testDeferredCreatedAfterSubscription() {
        var deferredCalled = false

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let sut: Publishers.Deferred = Publishers.Deferred { () -> CustomPublisher in
            deferredCalled = true
            return publisher
        }

        let tracking = TrackingSubscriber()

        XCTAssertEqual(subscription.history, [])
        XCTAssertFalse(deferredCalled)

        sut.subscribe(tracking)

        XCTAssertEqual(subscription.history, [])
        XCTAssertTrue(deferredCalled)

        subscription.request(.unlimited)
    }
}
