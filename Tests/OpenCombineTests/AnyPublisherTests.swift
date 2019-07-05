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
    ]

    private typealias Sut = AnyPublisher<Int, TestingError>

    func testErasePublisher() {

        let subscriber = TrackingSubscriber()
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual($0.combineIdentifier, subscriber.combineIdentifier)
            }
        )
        let erased = AnyPublisher(publisher)

        erased.receive(subscriber: subscriber)
        XCTAssertEqual(publisher.history, [.subscriber])
    }
}
