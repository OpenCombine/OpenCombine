//
//  EmptyTests.swift
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
final class EmptyTests: XCTestCase {

    static let allTests = [
        ("testEmpty", testEmpty),
        ("testImmediatelyCancel", testImmediatelyCancel),
    ]

    func testEmpty() {

        let completesImmediately = Publishers.Empty(completeImmediately: true,
                                                    outputType: Int.self,
                                                    failureType: TestingError.self)
        let subscriber = TrackingSubscriber()
        completesImmediately.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])

        let doesNotComplete = Publishers.Empty(completeImmediately: false,
                                               outputType: Int.self,
                                               failureType: TestingError.self)

        doesNotComplete.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished),
                                            .subscription("Empty")])
    }

    func testImmediatelyCancel() {
        let completesImmediately = Publishers.Empty(outputType: Int.self,
                                                    failureType: TestingError.self)

        let subscriber = TrackingSubscriber(receiveSubscription: { $0.cancel() })
        completesImmediately.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])
    }
}
