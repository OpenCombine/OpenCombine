//
//  AnyPublisherTests.swift
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

@available(macOS 10.15, iOS 13.0, *)
final class AnyPublisherTests: XCTestCase {

    private typealias Sut = AnyPublisher<Int, TestingError>

    func testErasePublisher() {

        let subscriber = TrackingSubscriber()
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual($0.combineIdentifier, subscriber.combineIdentifier)
            }
        )
        let erased = publisher.eraseToAnyPublisher()

        erased.subscribe(subscriber)
        XCTAssertEqual(publisher.history, [.subscriber])
    }

    @available(macOS 11.0, iOS 14.0, *)
    func testDoubleErasure() {
        let introspection = TrackingIntrospection()
        let subscriber = TrackingSubscriber()
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual($0.combineIdentifier, subscriber.combineIdentifier)
            }
        )

        let erasedOnce = publisher.eraseToAnyPublisher()
        let erasedTwice = erasedOnce.eraseToAnyPublisher()

        // Here we use the fact that AnyPublisher wraps a single private class instance.
        XCTAssert(
            unsafeBitCast(erasedOnce, to: AnyObject.self) ===
                unsafeBitCast(erasedTwice, to: AnyObject.self),
            "Rrasing a publisher twice shouldn't result in double boxing"
        )

        introspection.temporarilyEnable {
            erasedTwice.subscribe(subscriber)
        }

        XCTAssertEqual(publisher.history, [.subscriber])
        XCTAssertEqual(
            introspection.history,
            [.publisherWillReceiveSubscriber(.init(erasedTwice), .init(subscriber)),
             .publisherWillReceiveSubscriber(.anything, .init(subscriber)),
             .subscriberWillReceiveSubscription(.init(subscriber), "PassthroughSubject"),
             .subscriberDidReceiveSubscription(.init(subscriber), "PassthroughSubject"),
             .publisherDidReceiveSubscriber(.anything, .init(subscriber)),
             .publisherDidReceiveSubscriber(.init(erasedTwice), .init(subscriber))]
        )
    }

    func testDescription() {
        let erased = AnyPublisher(TrackingSubject<Int>())
        XCTAssertEqual(erased.description, "AnyPublisher")
        XCTAssertEqual(erased.description, erased.playgroundDescription as? String)
    }
}
