//
//  PublisherTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.07.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class PublisherTests: XCTestCase {

    static let allTests = [
        ("testSubscribeSubscriber", testSubscribeSubscriber),
        ("testSubscribeSubject", testSubscribeSubject),
        ("testSubjectSubscriber", testSubjectSubscriber),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    func testSubscribeSubscriber() {

        final class TrivialPublisher: Publisher {
            typealias Output = Int
            typealias Failure = TestingError

            private(set) var counter = 0

            func receive<SomeSubscriber: Subscriber>(
                subscriber: SomeSubscriber
            ) where Failure == SomeSubscriber.Failure, Output == SomeSubscriber.Input {
                counter += 1
            }
        }

        let publisher = TrivialPublisher()
        let subscriber = TrackingSubscriber()

        publisher.subscribe(subscriber)

        XCTAssertEqual(publisher.counter, 1)
        XCTAssert(subscriber.history.isEmpty)
    }

    func testSubscribeSubject() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let subject = TrackingSubject<Int>()

        let cancellable = publisher.subscribe(subject)

        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(subject.history, [.subscription("Subject")])

        XCTAssertEqual(publisher.send(0), .none)
        XCTAssertEqual(publisher.send(1), .none)

        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(subject.history, [.subscription("Subject"),
                                         .value(0),
                                         .value(1)])

        cancellable.cancel()

        XCTAssertEqual(publisher.send(2), .none)

        XCTAssertEqual(subscription.history, [.cancelled])
        XCTAssertEqual(subject.history, [.subscription("Subject"), .value(0), .value(1)])
    }

    func testSubjectSubscriber() throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        var subjectDestroyed = false
        do {
            let subject = TrackingSubject<Int>(onDeinit: { subjectDestroyed = true })

            let cancellable = publisher.subscribe(subject)

            try withExtendedLifetime(cancellable) {

                let subjectSubscription =
                    try XCTUnwrap(publisher.erasedSubscriber as? Subscription)

                XCTAssertEqual(String(describing: subjectSubscription), "Subject")

                subjectSubscription.request(.max(42))
                XCTAssertEqual(subscription.history, [.requested(.max(42))])

                subjectSubscription.cancel()
                subjectSubscription.cancel()
                XCTAssertEqual(subscription.history, [.requested(.max(42)), .cancelled])

                subjectSubscription.request(.max(37))
                XCTAssertEqual(subscription.history, [.requested(.max(42)), .cancelled])
            }
        }

        XCTAssert(subjectDestroyed)
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
