//
//  AnySubscriberTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class AnySubscriberTests: XCTestCase {

    static let allTests = [
        ("testCombineIdentifier", testCombineIdentifier),
        ("testDescription", testDescription),
    ]

    private typealias Sut = AnySubscriber<Int, TestingError>

    func testCombineIdentifier() {

        let empty = Sut()
        XCTAssertEqual(empty.combineIdentifier.description,
                       empty.combineIdentifier.description,
                       "combineIdentifier shouldn't change")

        let passthrough = PassthroughSubject<Int, TestingError>()
        let erasingPassthrough = Sut(passthrough)
        XCTAssertNotEqual(erasingPassthrough.combineIdentifier.description, "0x3")

        XCTAssertNotEqual(Sut(TrackingSubscriber()).combineIdentifier,
                          CombineIdentifier())

        do {
            let subscriber1 = TrackingSubscriber()
            let subscriber2 = TrackingSubscriber()
            XCTAssertNotEqual(Sut(subscriber1).combineIdentifier,
                              Sut(subscriber2).combineIdentifier)
        }

        do {
            let subscriber = TrackingSubscriber()
            XCTAssertEqual(subscriber.combineIdentifier, subscriber.combineIdentifier)
        }
    }

    func testDescription() {

        let empty = Sut()
        XCTAssertEqual(empty.description, "AnySubscriber")

        let passthrough = PassthroughSubject<Int, TestingError>()
        let erasingPassthrough = Sut(passthrough)
        XCTAssertEqual(erasingPassthrough.description, "PassthroughSubject<Int, TestingError>")
    }
}
