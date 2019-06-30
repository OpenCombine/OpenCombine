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

@available(macOS 10.15, *)
final class AnyPublisherTests: XCTestCase {

    static let allTests = [
        ("testErasePublisher", testErasePublisher),
        ("testClosureBasedPublisher", testClosureBasedPublisher),
    ]

    private typealias Sut = AnyPublisher<Int, TestingError>

    func testErasePublisher() {

        let publisher = TrackingSubject<Int>()
        let erased = AnyPublisher(publisher)
        let subscriber = TrackingSubscriber()

        erased.receive(subscriber: subscriber)
        XCTAssertEqual(publisher.history, [.subscriber(subscriber.combineIdentifier)])
    }

    func testClosureBasedPublisher() {

        var erasedSubscriber: AnySubscriber<Int, TestingError>?

        let erased = AnyPublisher<Int, TestingError> { erasedSubscriber = $0 }
        let subscriber = TrackingSubscriber()

        erased.receive(subscriber: subscriber)

        XCTAssertEqual(erasedSubscriber?.combineIdentifier, subscriber.combineIdentifier)
    }
}
