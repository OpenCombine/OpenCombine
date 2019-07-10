//
//  LastTests.swift
//  
//
//  Created by Joseph Spadafora on 7/9/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class LastTests: XCTestCase {
    static let allTests = [
        ("testReturnsLastValue", testReturnsLastValue),
        ("testCompletesWithError", testCompletesWithError)
    ]

    // swiftlint:disable implicitly_unwrapped_optional
    var subscription: CustomSubscription!
    var publisher: CustomPublisher!
    var tracking: TrackingSubscriber!
    var sut: Publishers.Last<CustomPublisher>!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        subscription = CustomSubscription()
        publisher = CustomPublisher(subscription: subscription)
        tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )
        sut = publisher.last()
    }

    func testReturnsLastValue() {
        sut.receive(subscriber: tracking)
        XCTAssertEqual(tracking.history, [.subscription("Last")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(1), .none)
        XCTAssertEqual(tracking.history, [.subscription("Last")])

        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(tracking.history, [.subscription("Last")])

        XCTAssertEqual(publisher.send(5), .none)
        XCTAssertEqual(tracking.history, [.subscription("Last")])

        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("Last"),
                                          .value(5),
                                          .completion(.finished)])

        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("Last"),
                                          .value(5),
                                          .completion(.finished)])
    }

    func testCompletesWithError() {
        sut.receive(subscriber: tracking)
        XCTAssertEqual(tracking.history, [.subscription("Last")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("Last"),
                                          .completion(.failure(.oops))])

        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("Last"),
                                          .completion(.failure(.oops))])

        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("Last"),
                                          .completion(.failure(.oops))])
    }
}
