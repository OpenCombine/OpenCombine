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

@available(macOS 10.15, *)
final class MulticastTests: XCTestCase {

    static let allTests = [
        ("testMulticast", testMulticast),
        ("testMulticastConnectTwice", testMulticastConnectTwice),
        ("testMulticastDisconnect", testMulticastDisconnect),
    ]

    func testMulticast() throws {

        let publisher = PassthroughSubject<Int, TestingError>()
        let multicast = publisher.multicast(PassthroughSubject.init)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

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

    func testMulticastConnectTwice() {

        let publisher = PassthroughSubject<Int, TestingError>()
        let multicast = publisher.multicast(PassthroughSubject.init)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        multicast.subscribe(tracking)

        publisher.send(-1)

        let connection1 = multicast.connect()
        let connection2 = multicast.connect()

        publisher.send(42)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .value(42),
                                          .completion(.finished)])

        connection1.cancel()
        connection2.cancel()
    }

    func testMulticastDisconnect() {

        let publisher = PassthroughSubject<Int, TestingError>()
        let multicast = publisher.multicast(PassthroughSubject.init)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        multicast.subscribe(tracking)

        publisher.send(-1)

        var connection = multicast.connect()

        publisher.send(42)
        connection.cancel()
        publisher.send(100)

        multicast.subscribe(tracking)
        connection = multicast.connect()
        publisher.send(2)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .subscription(Subscriptions.empty),
                                          .value(2),
                                          .value(2),
                                          .completion(.finished),
                                          .completion(.finished)])

        connection.cancel()
    }
}
