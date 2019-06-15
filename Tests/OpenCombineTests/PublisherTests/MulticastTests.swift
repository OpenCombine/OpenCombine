//
//  MulticastTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

// TODO: Semantics of Combine's Multicast is unclear. Waiting for the next beta?
/*
// The tests are taken from https://github.com/ReactiveX/RxJava/blob/b95e3dc2629d9eb1cda099d2fd061f9202f8fb5f/src/test/java/io/reactivex/internal/operators/observable/ObservableMulticastTest.java
@available(macOS 10.15, *)
final class MulticastTests: XCTestCase {

    static let allTests = [
        ("testMulticast", testMulticast),
    ]

    func testMulticast() throws {

        let publisher = PassthroughSubject<Int, TestingError>()
        let multicast = publisher.multicast(PassthroughSubject.init)
        let tracking = TrackingSubscriber()

        multicast.subscribe(tracking)

        publisher.send(0)
        publisher.send(12)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty)])

        var connection = multicast.connect()

        publisher.send(-1)
        publisher.send(42)

        connection.cancel()

        publisher.send(14)

        connection = multicast.connect()

        publisher.send(15)
        publisher.send(completion: .finished)

        connection.cancel()

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(-1),
                                          .value(42),
                                          .value(15),
                                          .completion(.finished)])
    }
}
*/
