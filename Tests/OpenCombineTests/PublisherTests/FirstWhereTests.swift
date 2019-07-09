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
final class FirstTests: XCTestCase {
    
    static let allTests = [
        ("testFirstFinishesAndReturnsFirstItem",
            testFirstFinishesAndReturnsFirstItem),
        ("testFirstFinishesWithError",
            testFirstFinishesWithError),
        ("testFirstFinishesFinishesImmediately", testFirstFinishesFinishesImmediately)
    ]
    
    func testFirstFinishesAndReturnsFirstItem() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        
        let sut = publisher.first()
        
        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])
        
        sut.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("First")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        
        let sentDemand = publisher.send(25)
        XCTAssertEqual(sentDemand, .none)
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .value(25),
                                          .completion(.finished)])
        
        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .value(25),
                                          .completion(.finished)])
        
        let afterFinishSentDemand = publisher.send(73)
        XCTAssertEqual(afterFinishSentDemand, .none)
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .value(25),
                                          .completion(.finished)])
        
    }
    
    func testFirstFinishesWithError() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        
        let sut = publisher.first()
        
        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])
        
        sut.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("First")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        
        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .completion(.failure(.oops))])
        
        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .completion(.failure(.oops))])
        
        let afterFinishSentDemand = publisher.send(73)
        XCTAssertEqual(afterFinishSentDemand, .none)
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .completion(.failure(.oops))])
        
    }
    
    
    func testFirstFinishesFinishesImmediately() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        
        let sut = publisher.first()
        
        XCTAssertEqual(tracking.history, [])
        XCTAssertEqual(subscription.history, [])
        
        sut.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("First")])
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        
        publisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .completion(.finished)])
        
        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .completion(.finished)])
        
        let afterFinishSentDemand = publisher.send(73)
        XCTAssertEqual(afterFinishSentDemand, .none)
        XCTAssertEqual(tracking.history, [.subscription("First"),
                                          .completion(.finished)])
        
    }
}

@available(macOS 10.15, *)
final class FirstWhereTests: XCTestCase {
    
    static let allTests = [
        ("testFirstFinishesAndReturnsFirstMatchingItem",
            testFirstFinishesAndReturnsFirstMatchingItem),
        ("testFirstWhereFinishesWithError",
            testFirstWhereFinishesWithError)
    ]
    
    func testFirstFinishesAndReturnsFirstMatchingItem() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        
        let sut = publisher.first(where: { $0.isMultiple(of: 2) })
        
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
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        let sut = publisher.first { $0.isMultiple(of: 2) }

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

//@available(macOS 10.15, *)
//final class TryFirstWhereTests: XCTestCase {
//
//    static let allTests = [
//        ("testFirstFinishesAndReturnsFirstItem",
//         testFirstFinishesAndReturnsFirstItem),
//        ("testFirstFinishesWithError",
//         testFirstFinishesWithError),
//        ("testFirstFinishesFinishesImmediately", testFirstFinishesFinishesImmediately)
//    ]
//
//    func testFirstFinishesAndReturnsFirstItem() {
//        let subscription = CustomSubscription()
//        let publisher = CustomPublisher(subscription: subscription)
//        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
//
//        let sut = publisher.first()
//
//        XCTAssertEqual(tracking.history, [])
//        XCTAssertEqual(subscription.history, [])
//
//        sut.subscribe(tracking)
//        XCTAssertEqual(tracking.history, [.subscription("First")])
//        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
//
//        let sentDemand = publisher.send(25)
//        XCTAssertEqual(sentDemand, .none)
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .value(25),
//                                          .completion(.finished)])
//
//        publisher.send(completion: .finished)
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .value(25),
//                                          .completion(.finished)])
//
//        let afterFinishSentDemand = publisher.send(73)
//        XCTAssertEqual(afterFinishSentDemand, .none)
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .value(25),
//                                          .completion(.finished)])
//
//    }
//
//    func testFirstFinishesWithError() {
//        let subscription = CustomSubscription()
//        let publisher = CustomPublisher(subscription: subscription)
//        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
//
//        let sut = publisher.first()
//
//        XCTAssertEqual(tracking.history, [])
//        XCTAssertEqual(subscription.history, [])
//
//        sut.subscribe(tracking)
//        XCTAssertEqual(tracking.history, [.subscription("First")])
//        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
//
//        publisher.send(completion: .failure(.oops))
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .completion(.failure(.oops))])
//
//        publisher.send(completion: .failure(.oops))
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .completion(.failure(.oops))])
//
//        let afterFinishSentDemand = publisher.send(73)
//        XCTAssertEqual(afterFinishSentDemand, .none)
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .completion(.failure(.oops))])
//
//    }
//
//
//    func testFirstFinishesFinishesImmediately() {
//        let subscription = CustomSubscription()
//        let publisher = CustomPublisher(subscription: subscription)
//        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
//
//        let sut = publisher.first()
//
//        XCTAssertEqual(tracking.history, [])
//        XCTAssertEqual(subscription.history, [])
//
//        sut.subscribe(tracking)
//        XCTAssertEqual(tracking.history, [.subscription("First")])
//        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
//
//        publisher.send(completion: .finished)
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .completion(.finished)])
//
//        publisher.send(completion: .failure(.oops))
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .completion(.finished)])
//
//        let afterFinishSentDemand = publisher.send(73)
//        XCTAssertEqual(afterFinishSentDemand, .none)
//        XCTAssertEqual(tracking.history, [.subscription("First"),
//                                          .completion(.finished)])
//
//    }
//}
