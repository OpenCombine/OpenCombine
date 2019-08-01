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

@available(macOS 10.15, iOS 13.0, *)
final class DeferredTests: XCTestCase {

    static let allTests = [
        ("testDeferredCreatedAfterSubscription",
            testDeferredCreatedAfterSubscription),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

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

    // MARK: -
    func testTestSuiteIncludesAllTests() {
        // https://oleb.net/blog/2017/03/keeping-xctest-in-sync/
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let thisClass = type(of: self)
        let allTestsCount = thisClass.allTests.count
        let darwinCount = thisClass.defaultTestSuite.testCaseCount
        XCTAssertEqual(allTestsCount,
                       darwinCount,
                       "\(darwinCount - allTestsCount) tests are missing from allTests")
#endif
    }
}
