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
        ("testDeferredCreatedAfterSubscription",
            testDeferredCreatedAfterSubscription)
    ]

    func testDeferredCreatedAfterSubscription() {
        var deferredPublisherCreatedCount = 0

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let sut: Publishers.Deferred = Publishers.Deferred { () -> CustomPublisher in
            deferredPublisherCreatedCount += 1
            return publisher
        }

        let tracking = TrackingSubscriber()

        XCTAssertEqual(deferredPublisherCreatedCount, 0)
        XCTAssertEqual(tracking.history, [])

        sut.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])
        XCTAssertEqual(deferredPublisherCreatedCount, 1)

        sut.subscribe(tracking)

        XCTAssertEqual(deferredPublisherCreatedCount, 2)

        subscription.request(.unlimited)

        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .subscription("CustomSubscription")])
    }
}
