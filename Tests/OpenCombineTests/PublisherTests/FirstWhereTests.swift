//
//  FirstWhereTests.swift
//  
//
//  Created by Joseph Spadafora on 7/8/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class FirstWhereTests: XCTestCase {

    static let allTests = [
        ("testFirstFinishesAndReturnsFirstMatchingItem",
            testFirstFinishesAndReturnsFirstMatchingItem),
        ("testFirstWhereFinishesWithError",
            testFirstWhereFinishesWithError)
    ]

    // swiftlint:disable implicitly_unwrapped_optional
    var subscription: CustomSubscription!
    var publisher: CustomPublisher!
    var tracking: TrackingSubscriber!
    var sut: Publishers.FirstWhere<CustomPublisher>!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        subscription = CustomSubscription()
        publisher = CustomPublisher(subscription: subscription)
        tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        sut = publisher.first(where: { $0.isMultiple(of: 2) })
    }

    func testFirstFinishesAndReturnsFirstMatchingItem() {
        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])

        sut.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("TryFirst")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        let demand1 = publisher.send(3)
        XCTAssertEqual(demand1, .none)
        XCTAssertEqual(tracking.history, [.subscription("TryFirst")])

        let demand2 = publisher.send(2)
        XCTAssertEqual(demand2, .none)
        XCTAssertEqual(tracking.history, [.subscription("TryFirst"),
                                          .value(2),
                                          .completion(.finished)])

        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("TryFirst"),
                                          .value(2),
                                          .completion(.finished)])

        let afterFinishSentDemand = publisher.send(4)
        XCTAssertEqual(afterFinishSentDemand, .none)
        XCTAssertEqual(tracking.history, [.subscription("TryFirst"),
                                          .value(2),
                                          .completion(.finished)])
    }

    func testFirstWhereFinishesWithError() {
        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])

        sut.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("TryFirst")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])

        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("TryFirst"),
                                          .completion(.failure(.oops))])

        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("TryFirst"),
                                          .completion(.failure(.oops))])

        let afterFinishSentDemand = publisher.send(73)
        XCTAssertEqual(afterFinishSentDemand, .none)
        XCTAssertEqual(tracking.history, [.subscription("TryFirst"),
                                          .completion(.failure(.oops))])
    }
}
