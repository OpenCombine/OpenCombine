//
//  FailTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 19.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class FailTests: XCTestCase {

    static let allTests = [
        ("testSubscription", testSubscription),
    ]

    private typealias Sut = Fail<Int, TestingError>

    func testSubscription() {
        let just = Sut(error: .oops)
        let tracking = TrackingSubscriber()
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Empty"),
                                          .completion(.failure(.oops))])
    }
}
