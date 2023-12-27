//
//  DeferredTests.swift
//  
//
//  Created by Joseph Spadafora on 7/7/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class DeferredTests: XCTestCase {

    func testDeferredCreatedAfterSubscription() {
        var deferredPublisherCreatedCount = 0

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let deferred = Deferred { () -> CustomPublisher in
            deferredPublisherCreatedCount += 1
            return publisher
        }

        let tracking = TrackingSubscriber()

        XCTAssertEqual(deferredPublisherCreatedCount, 0)
        XCTAssertEqual(tracking.history, [])

        deferred.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription")])
        XCTAssertEqual(deferredPublisherCreatedCount, 1)

        deferred.subscribe(tracking)

        XCTAssertEqual(deferredPublisherCreatedCount, 2)

        subscription.request(.unlimited)

        XCTAssertEqual(tracking.history, [.subscription("CustomSubscription"),
                                          .subscription("CustomSubscription")])
    }
}
