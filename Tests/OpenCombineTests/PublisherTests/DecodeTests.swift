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
        ("testDownstraemReceivesFailure", testDownstreamReceivesFailure)
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
        guard case .completion(.failure) = subscriber.history[1] else {
            XCTFail("Decode failure not found")
            return
        }
    }
}

let testValue = ["test": "TestDecodable"]
