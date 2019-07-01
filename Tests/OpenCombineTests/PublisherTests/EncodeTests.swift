//
//  EncodeTests.swift
//
//
//  Created by Joseph Spadafora on 6/21/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class EncodeTests: XCTestCase {
    static let allTests = [
        ("testEncodeWorks", testEncodeWorks),
        ("testDemand", testDemand),
        ("testEncodeSuccessHistory", testEncodeSuccessHistory)
    ]

    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    func testEncodeWorks() throws {
        // Given
        let testValue = ["test": "TestDecodable"]
        let subject = PassthroughSubject<[String: String], Error>()
        let publisher = subject.encode(encoder: jsonEncoder)
        let subscriber = TrackingSubscriberBase<Data, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        // When
        publisher.subscribe(subscriber)
        subject.send(testValue)

        // Then
        guard case let .value(data) = subscriber.history[1] else {
            XCTFail("No encoded data found")
            return
        }

        let decoded = try jsonDecoder.decode([String: String].self, from: data)
        XCTAssert(decoded == testValue)
    }

    func testEncodeSuccessHistory() throws {
        // Given
        let testValue = ["test": "TestDecodable"]
        let subject = PassthroughSubject<[String: String], Error>()
        let publisher = subject.encode(encoder: jsonEncoder)
        let subscriber = TrackingSubscriberBase<Data, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        // When
        publisher.subscribe(subscriber)
        subject.send(testValue)

        // Then
        let testData = try jsonEncoder.encode(testValue)
        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(testData)])
    }

    func testDemand() {
        // `CustomSubscription` tracks all the requests and cancellations
        // in its `history` property
        let subscription = CustomSubscription()

        // `CustomPublisher` sends the subscription object it has been initialized with
        // to whoever subscribed to the `CustomPublisher`.
        let publisher = CustomPublisherBase<[String: String]>(subscription: subscription)

        // `_Encode` helper will receive the `CustomSubscription `
        let encode = publisher.encode(encoder: jsonEncoder)

        // This is actually `_Decode`
        var downstreamSubscription: Subscription?

        // `TrackingSubscriber` records every event like "receiveSubscription",
        // "receiveValue" and "receiveCompletion" into its `history` property,
        // optionally executing the provided callbacks.
        let tracking = TrackingSubscriberBase<Data, Error>(
            receiveSubscription: {
                $0.request(.max(37))
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(2) }
        )

        encode.subscribe(tracking)
        XCTAssertNotNil(downstreamSubscription) // Removes unused variable warning
        XCTAssertEqual(subscription.history, [.requested(.max(37))])
    }
}
