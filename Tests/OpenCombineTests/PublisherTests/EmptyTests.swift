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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class EmptyTests: XCTestCase {

    func testEmpty() {

        let completesImmediately = Empty(completeImmediately: true,
                                         outputType: Int.self,
                                         failureType: TestingError.self)
        let subscriber = TrackingSubscriber()
        completesImmediately.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])

        let doesNotComplete = Empty(completeImmediately: false,
                                    outputType: Int.self,
                                    failureType: TestingError.self)

        doesNotComplete.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished),
                                            .subscription("Empty")])
    }

    func testImmediatelyCancel() {
        let completesImmediately = Empty(outputType: Int.self,
                                         failureType: TestingError.self)

        let subscriber = TrackingSubscriber(receiveSubscription: { $0.cancel() })
        completesImmediately.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])
    }

    func testEquatable() {
        XCTAssertEqual(Empty(completeImmediately: true,
                             outputType: Int.self,
                             failureType: Error.self),
                       Empty(completeImmediately: true,
                             outputType: Int.self,
                             failureType: Error.self))
        XCTAssertEqual(Empty(completeImmediately: false,
                             outputType: Int.self,
                             failureType: Error.self),
                       Empty(completeImmediately: false,
                             outputType: Int.self,
                             failureType: Error.self))
        XCTAssertNotEqual(Empty(completeImmediately: true,
                                outputType: Int.self,
                                failureType: Error.self),
                          Empty(completeImmediately: false,
                                outputType: Int.self,
                                failureType: Error.self))
    }
}
