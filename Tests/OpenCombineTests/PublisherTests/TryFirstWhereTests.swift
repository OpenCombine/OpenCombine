//
//  TryFirstWhereTests.swift
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
final class TryFirstWhereTests: XCTestCase {

    static let allTests = [
        ("testReturnsFirstMatchingElement", testReturnsFirstMatchingElement),
        ("testTryFirstWhereFinishesWithError", testTryFirstWhereFinishesWithError),
        ("testFirstWhereFinishesWhenErrorThrown", testFirstWhereFinishesWhenErrorThrown)
    ]

    // swiftlint:disable implicitly_unwrapped_optional
    var subscription: CustomSubscription!
    var publisher: CustomPublisher!
    var tracking: TrackingSubscriberBase<Int, Error>!
    var sut: Publishers.TryFirstWhere<CustomPublisher>!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        subscription = CustomSubscription()
        publisher = CustomPublisher(subscription: subscription)
        tracking = TrackingSubscriberBase<Int, Error>(receiveSubscription: {
            $0.request(.unlimited)
        })
        sut = publisher.tryFirst(where: { $0.isMultiple(of: 7) })
    }

    func testReturnsFirstMatchingElement() {
        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])

        sut.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        for number in 1...6 {
            let sentDemand = publisher.send(number)
            XCTAssertEqual(sentDemand, .none)
            XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere")])
        }

        XCTAssertEqual(publisher.send(7), .none)
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere"),
                                          .value(7),
                                          .completion(.finished)])
    }

    func testTryFirstWhereFinishesWithError() {
        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])

        sut.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere"),
                                          .completion(.failure(TestingError.oops))])

        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere"),
                                          .completion(.failure(TestingError.oops))])

        let afterFinishSentDemand = publisher.send(73)
        XCTAssertEqual(afterFinishSentDemand, .none)
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere"),
                                          .completion(.failure(TestingError.oops))])
    }

    func testFirstWhereFinishesWhenErrorThrown() {
        sut = publisher.tryFirst(where: {
            if $0 == 3 {
                throw TestingError.oops
            }
            return false
        })

        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])

        sut.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(publisher.send(3), .none)
        XCTAssertEqual(tracking.history, [.subscription("TryFirstWhere"),
                                          .completion(.failure(TestingError.oops))])
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }
}
