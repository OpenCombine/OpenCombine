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

    var jsonEncoder: TestEncoder = TestEncoder()
    var jsonDecoder: TestDecoder = TestDecoder()

    override func setUp() {
        super.setUp()
        jsonEncoder = TestEncoder()
        jsonDecoder = TestDecoder()
    }

    func testDecodeWorks() throws {
        // Given
        let data = 78 // Represents decodable data
        let subject = PassthroughSubject<Int, Error>()
        let publisher = subject.decode(type: [String: String].self, decoder: jsonDecoder)
        let subscriber = TrackingSubscriberBase<[String: String], Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        jsonDecoder.handleDecode = { decodeData in
            if decodeData == data {
                return testValue
            }
            return nil
        }

        // When
        publisher.subscribe(subscriber)
        subject.send(data)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(testValue)])
    }

    func testDownstreamReceivesFailure() {
        // Given
        let failData = 95
        let subject = PassthroughSubject<Int, Error>()
        let publisher = subject.decode(type: [String: String].self, decoder: jsonDecoder)
        let subscriber =  TrackingSubscriberBase<[String: String], Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        // When
        publisher.subscribe(subscriber)
        subject.send(failData)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .completion(.failure(TestDecoder.error))])
    }

    func testDemand() {
        // `CustomSubscription` tracks all the requests and cancellations
        // in its `history` property
        let subscription = CustomSubscription()

        // `CustomPublisher` sends the subscription object it has been initialized with
        // to whoever subscribed to the `CustomPublisher`.
        let publisher = CustomPublisherBase<Int>(subscription: subscription)

        // `_Decode` helper will receive the `CustomSubscription `
        let decode = publisher.decode(type: [String : String].self,
                                      decoder: jsonDecoder)

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
        XCTAssertEqual(subscription.history, [.requested(.max(42))])
    }
}

let testValue = ["test": "TestDecodable"]
