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

    private var encoder = TestEncoder()
    private var decoder = TestDecoder()

    override func setUp() {
        super.setUp()
        encoder = TestEncoder()
        decoder = TestDecoder()
    }

    func testEncodeWorks() throws {
        // Given
        let testValue = ["test": "TestDecodable"]
        let subject = PassthroughSubject<[String: String], Error>()
        let publisher = subject.encode(encoder: encoder)
        let subscriber = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        // When
        publisher.subscribe(subscriber)
        subject.send(testValue)

        // Then
        XCTAssert(encoder.encoded.first?.value as? [String: String] == testValue)
    }

    func testEncodeSuccessHistory() throws {
        // Given
        let testValue = ["test": "TestDecodable"]
        let subject = PassthroughSubject<[String: String], Error>()
        let publisher = subject.encode(encoder: encoder)
        let subscriber = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        // When
        publisher.subscribe(subscriber)
        subject.send(testValue)

        // Then
        guard let testKey = encoder.encoded.first?.key, encoder.encoded.count == 1 else {
            XCTFail("Could not get testing data from encoding")
            return
        }
        XCTAssertEqual(subscriber.history, [.subscription("Encode"),
                                            .value(testKey)])
    }

    func testDemand() {
        // `CustomSubscription` tracks all the requests and cancellations
        // in its `history` property
        let subscription = CustomSubscription()

        // `CustomPublisher` sends the subscription object it has been initialized with
        // to whoever subscribed to the `CustomPublisher`.
        let publisher = CustomPublisherBase<[String: String]>(subscription: subscription)

        // `_Encode` helper will receive the `CustomSubscription `
        let encode = publisher.encode(encoder: encoder)

        // This is actually `_Decode`
        var downstreamSubscription: Subscription?

        // `TrackingSubscriber` records every event like "receiveSubscription",
        // "receiveValue" and "receiveCompletion" into its `history` property,
        // optionally executing the provided callbacks.
        let tracking = TrackingSubscriberBase<Int, Error>(
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
