//
//  CatchTests.swift
//  
//
//  Created by Max Desiatov on 25/12/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CatchTests: XCTestCase {
    private typealias Sut = Future<Int, TestingError>

    func testSimpleCatch() {
        enum SimpleError: Error { case error }
        let noErrorPublisher = Publishers.Sequence<Range<Int>, SimpleError>(
            sequence: 0..<10
        ).tryMap { v -> Int in
            if v < 5 {
                return v
            } else {
                throw SimpleError.error
            }
        }.catch { _ in
            Just(100)
        }


        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: { _ in .max(1) }
        )
        noErrorPublisher.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Catch"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .value(100),
                                          .completion(.finished)])
    }
}
