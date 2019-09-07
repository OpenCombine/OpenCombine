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

@available(macOS 10.15, iOS 13.0, *)
final class EncodeTests: XCTestCase {

    private var encoder = TestEncoder()
    private var decoder = TestDecoder()

    override func setUp() {
        super.setUp()
        encoder = TestEncoder()
        decoder = TestDecoder()
    }

    func testEncodingSuccess() throws {
        let testValue = ["test" : "TestDecodable"]
        let subject = PassthroughSubject<[String : String], Error>()
        let publisher = subject.encode(encoder: encoder)
        let subscriber = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.subscribe(subscriber)
        subject.send(testValue)

        XCTAssertEqual(encoder.encoded.first?.value as? [String : String], testValue)
    }

    func testEncodingFailure() throws {
        let testValue = ["test" : "TestDecodable"]
        let subject = PassthroughSubject<[String : String], Error>()

        encoder.handleEncode = { _ in throw TestingError.oops }

        let publisher = subject.encode(encoder: encoder)
        let subscriber = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.subscribe(subscriber)
        subject.send(testValue)

        XCTAssertEqual(subscriber.history, [.subscription("Encode"),
                                            .completion(.failure(TestingError.oops))])
    }

    func testEncodeSuccessHistory() throws {
        let testValue = ["test" : "TestDecodable"]
        let subject = PassthroughSubject<[String : String], Error>()
        let publisher = subject.encode(encoder: encoder)
        let subscriber = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.subscribe(subscriber)
        subject.send(testValue)

        guard let testKey = encoder.encoded.first?.key, encoder.encoded.count == 1 else {
            XCTFail("Could not get testing data from encoding")
            return
        }
        XCTAssertEqual(subscriber.history, [.subscription("Encode"),
                                            .value(testKey)])
    }

    func testDemand() {
        let subscription = CustomSubscription()

        let publisher = CustomPublisherBase<[String : String], TestingError>(
            subscription: subscription
        )

        let encode = publisher.encode(encoder: encoder)

        var downstreamSubscription: Subscription?

        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: {
                $0.request(.max(37))
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(2) }
        )

        encode.subscribe(tracking)
        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(publisher.send(["test" : "TestDecodable"]), .max(2))
        XCTAssertEqual(subscription.history, [.requested(.max(37))])
    }
}
