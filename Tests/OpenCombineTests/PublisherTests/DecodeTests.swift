//
//  DecodeTests.swift
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
final class DecodeTests: XCTestCase {
    static let allTests = [
        ("testDecodeWorks", testDecodeWorks),
        ("testDownstraemReceivesFailure", testDownstreamReceivesFailure),
        ("testDemand", testDemand)
    ]

    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    func testDecodeWorks() throws {
        // Given
        let data = try jsonEncoder.encode(testValue)
        let subject = PassthroughSubject<Data, Error>()
        let publisher = subject.decode(type: [String: String].self, decoder: jsonDecoder)
        let subscriber = TrackingSubscriberBase<[String: String], Error>()

        // When
        publisher.subscribe(subscriber)
        subject.send(data)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(testValue)])
    }

    func testDownstreamReceivesFailure() {
        // Given
        let failData = Data("whoops".utf8)
        let subject = PassthroughSubject<Data, Error>()
        let publisher = subject.decode(type: [String: String].self, decoder: jsonDecoder)
        let subscriber = TrackingSubscriberBase<[String: String], Error>()

        // When
        publisher.subscribe(subscriber)
        subject.send(failData)

        // Then
        let decodeContext = DecodingError.Context(codingPath: [], debugDescription: "")
        let decodeError = DecodingError.dataCorrupted(decodeContext)
        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .completion(.failure(decodeError))])
    }

    func testDemand() {
        // `CustomSubscription` tracks all the requests and cancellations
        // in its `history` property
        let subscription = CustomSubscription()

        // `CustomPublisher` sends the subscription object it has been initialized with
        // to whoever subscribed to the `CustomPublisher`.
        let publisher = CustomPublisherBase<Data>(subscription: subscription)

        // `_Decode` helper will receive the `CustomSubscription `
        let decode = publisher.decode(type: [String : String].self,
                                      decoder: JSONDecoder())

        // This is actually `_Decode`
        var downstreamSubscription: Subscription?

        // `TrackingSubscriber` records every event like "receiveSubscription",
        // "receiveValue" and "receiveCompletion" into its `history` property,
        // optionally executing the provided callbacks.
        let tracking = TrackingSubscriberBase<[String: String], Error>(
            receiveSubscription: {
                $0.request(.max(42))
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(2) }
        )

        decode.subscribe(tracking)
        XCTAssertNotNil(downstreamSubscription) // Removes unused variable warning
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
    }
}

let testValue = ["test": "TestDecodable"]
