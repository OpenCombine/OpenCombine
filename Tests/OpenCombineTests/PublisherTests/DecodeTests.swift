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

@available(macOS 10.15, iOS 13.0, *)
final class DecodeTests: XCTestCase {
    static let allTests = [
        ("testDecodingSuccess", testDecodingSuccess),
        ("testDecodingFailure", testDecodingFailure),
        ("testDemand", testDemand),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    var jsonEncoder: TestEncoder = TestEncoder()
    var jsonDecoder: TestDecoder = TestDecoder()

    override func setUp() {
        super.setUp()
        jsonEncoder = TestEncoder()
        jsonDecoder = TestDecoder()
    }

    func testDecodingSuccess() throws {
        let data = 78
        let subject = PassthroughSubject<Int, Error>()
        let publisher = subject.decode(type: [String : String].self, decoder: jsonDecoder)
        let subscriber = TrackingSubscriberBase<[String: String], Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        jsonDecoder.handleDecode = { decodeData in
            if decodeData == data {
                return testValue
            }
            return nil
        }

        publisher.subscribe(subscriber)
        subject.send(data)
        subject.send(completion: .finished)

        XCTAssertEqual(subscriber.history, [.subscription("Decode"),
                                            .value(testValue),
                                            .completion(.finished)])
    }

    func testDecodingFailure() {
        let failData = 95
        let subject = PassthroughSubject<Int, Error>()
        let publisher = subject.decode(type: [String : String].self, decoder: jsonDecoder)
        let subscriber =  TrackingSubscriberBase<[String: String], Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.subscribe(subscriber)
        subject.send(failData)

        XCTAssertEqual(subscriber.history, [.subscription("Decode"),
                                            .completion(.failure(TestDecoder.error))])
    }

    func testDemand() {
        let subscription = CustomSubscription()

        let publisher = CustomPublisherBase<Int, TestingError>(subscription: subscription)

        let decode = publisher.decode(type: [String : String].self,
                                      decoder: jsonDecoder)

        var downstreamSubscription: Subscription?

        let tracking = TrackingSubscriberBase<[String : String], Error>(
            receiveSubscription: {
                $0.request(.max(42))
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(2) }
        )

        decode.subscribe(tracking)
        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(publisher.send(10), .none)
        XCTAssertEqual(subscription.history, [.requested(.max(42)), .cancelled])
    }

    // MARK: -
    func testTestSuiteIncludesAllTests() {
        // https://oleb.net/blog/2017/03/keeping-xctest-in-sync/
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let thisClass = type(of: self)
        let allTestsCount = thisClass.allTests.count
        let darwinCount = thisClass.defaultTestSuite.testCaseCount
        XCTAssertEqual(allTestsCount,
                       darwinCount,
                       "\(darwinCount - allTestsCount) tests are missing from allTests")
#endif
    }
}

let testValue = ["test": "TestDecodable"]
