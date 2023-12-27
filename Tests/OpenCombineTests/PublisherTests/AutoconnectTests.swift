//
//  AutoconnectTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 25/09/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class AutoconnectTests: XCTestCase {

    func testBasicRefcountBehavior() throws {

        let subscription = CustomSubscription()
        let publisher = CustomConnectablePublisher(subscription: subscription)

        let autoconnect = publisher.autoconnect()

        XCTAssertEqual(publisher.connectionHistory, [])

        let subscriber1 = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(101)) },
            receiveValue: { _ in .max(201) }
        )
        let subscriber2 = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(102)) },
            receiveValue: { _ in .max(202) }
        )
        let subscriber3 = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(103)) },
            receiveValue: { _ in .max(203) }
        )

        autoconnect.subscribe(subscriber1) // refcount = 1
        XCTAssertEqual(publisher.connectionHistory, [.connected])

        autoconnect.subscribe(subscriber2) // refcount = 2
        XCTAssertEqual(publisher.connectionHistory, [.connected])

        autoconnect.subscribe(subscriber3) // refcount = 3
        XCTAssertEqual(publisher.connectionHistory, [.connected])

        // Autoconnect should just forward events downstream
        XCTAssertEqual(publisher.send(1), .max(203))
        XCTAssertEqual(publisher.send(2), .max(203))
        publisher.send(completion: .finished)
        XCTAssertEqual(publisher.send(3), .max(203))
        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .failure(.oops))

        let subscription1 = try XCTUnwrap(subscriber1.subscriptions.first?.underlying)
        let subscription2 = try XCTUnwrap(subscriber2.subscriptions.first?.underlying)
        let subscription3 = try XCTUnwrap(subscriber3.subscriptions.first?.underlying)

        subscription2.cancel() // refcount = 2
        XCTAssertEqual(publisher.connectionHistory, [.connected])

        subscription3.cancel() // refcount = 1
        XCTAssertEqual(publisher.connectionHistory, [.connected])

        subscription1.cancel() // refcount = 0
        XCTAssertEqual(publisher.connectionHistory, [.connected, .disconnected])

        // Cancelling the same subscription twice shouldn't matter
        subscription1.cancel()
        XCTAssertEqual(publisher.connectionHistory, [.connected, .disconnected])

        XCTAssertEqual(subscription.history, [.requested(.max(101)),
                                              .requested(.max(102)),
                                              .requested(.max(103)),
                                              .cancelled,
                                              .cancelled,
                                              .cancelled,
                                              .cancelled])

        XCTAssertEqual(subscriber3.history, [.subscription("CustomSubscription"),
                                             .value(1),
                                             .value(2),
                                             .completion(.finished),
                                             .value(3),
                                             .completion(.failure(.oops)),
                                             .completion(.failure(.oops))])
    }

    func testReentranceWhenConnecting() throws {

        let subscription = CustomSubscription()
        let publisher = CustomConnectablePublisher(subscription: subscription)

        let autoconnect = publisher.autoconnect()

        let subscriber1 = TrackingSubscriber()

        let subscriber2 = TrackingSubscriber(
            receiveSubscription: { _ in autoconnect.subscribe(subscriber1) }
        )

        XCTAssertEqual(publisher.connectionHistory, [])

        autoconnect.subscribe(subscriber2)
        XCTAssertEqual(publisher.connectionHistory, [.connected,
                                                     .connected])

        try XCTUnwrap(subscriber2.subscriptions.first?.underlying).cancel()
        XCTAssertEqual(publisher.connectionHistory, [.connected,
                                                     .connected,
                                                     .disconnected])

        try XCTUnwrap(subscriber1.subscriptions.first?.underlying).cancel()
        XCTAssertEqual(publisher.connectionHistory, [.connected,
                                                     .connected,
                                                     .disconnected])
    }

    func testAutoconnectReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(0)],
                                                              demand: .max(42)),
                                           { $0.autoconnect() })
    }

    func testAutoconnectReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.autoconnect() }
        )
    }

    func testAutoconnectReflection() throws {

        let customMirrorPredicate = expectedChildren(
            ("parent", .contains("""
                                 Publishers.Autoconnect<\
                                 OpenCombineTests.\
                                 CustomConnectablePublisherBase<Swift.Int, \
                                 OpenCombineTests.TestingError>
                                 """)),
            ("downstream", "TrackingSubscriberBase<Int, TestingError>: []")
        )

        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "Autoconnect",
                           customMirror: customMirrorPredicate,
                           playgroundDescription: "Autoconnect",
                           subscriberIsAlsoSubscription: false,
                           { $0.autoconnect() })

        let subscription = CustomSubscription()
        let autoconnect = CustomConnectablePublisher(subscription: subscription)
            .autoconnect()

        try testSubscriptionReflection(
            description: "CustomSubscription",
            customMirror: nil,
            playgroundDescription: "CustomSubscription",
            sut: autoconnect
        )

        var autoconnectSubscriptionCombineID: CombineIdentifier?
        autoconnect.subscribe(
            TrackingSubscriber(
                receiveSubscription: {
                    autoconnectSubscriptionCombineID = $0.combineIdentifier
                }
            )
        )

        XCTAssertEqual(autoconnectSubscriptionCombineID, subscription.combineIdentifier)
    }
}
