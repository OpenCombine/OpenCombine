//
//  DropWhileTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

// TODO: add tests from https://github.com/ReactiveX/RxJava/blob/83f2bd771ee172a2154e0fb30c5ffcaf8f71433c/src/test/java/io/reactivex/internal/operators/observable/ObservableSkipWhileTest.java

@available(macOS 10.15, *)
final class DropWhileTests: XCTestCase {

    static let allTests = [
        ("testDropWhile", testDropWhile),
        ("testTryDropWhileFailureBecauseOfThrow", testTryDropWhileFailureBecauseOfThrow),
        ("testTryDropWhileFailureOnCompletion", testTryDropWhileFailureOnCompletion),
        ("testDemand", testDemand),
        ("testTryDropWhileCancelsUpstreamOnThrow",
         testTryDropWhileCancelsUpstreamOnThrow),
        ("testDropWhileCompletion",
         testDropWhileCompletion),
    ]

    func testDropWhile() {

        var counter = 0 // How many times the predicate is called?

        let publisher = PassthroughSubject<Int, TestingError>()
        let drop = publisher.drop(while: { counter += 1; return $0.isMultiple(of: 2) })
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        publisher.send(1)
        drop.subscribe(tracking)
        publisher.send(2)
        publisher.send(4)
        publisher.send(6)
        publisher.send(7)
        publisher.send(8)
        publisher.send(9)
        publisher.send(completion: .finished)
        publisher.send(10)

        XCTAssertEqual(tracking.history, [.subscription("DropWhile"),
                                          .value(7),
                                          .value(8),
                                          .value(9),
                                          .completion(.finished)])

        XCTAssertEqual(counter, 4)
    }

    func testTryDropWhileFailureBecauseOfThrow() {

        var counter = 0 // How many times the predicate is called?

        let publisher = PassthroughSubject<Int, Error>()
        let drop = publisher.tryDrop {
            counter += 1
            if $0 == 100 {
                throw "too much" as TestingError
            }
            return $0.isMultiple(of: 2)
        }
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.send(1)
        drop.subscribe(tracking)
        publisher.send(2)
        publisher.send(4)
        publisher.send(100)
        publisher.send(9)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history,
                       [.subscription("DropWhile"),
                        .completion(.failure("too much" as TestingError))])

        XCTAssertEqual(counter, 3)
    }

    func testTryDropWhileFailureOnCompletion() {

        let publisher = PassthroughSubject<Int, Error>()
        let drop = publisher.tryDrop { $0.isMultiple(of: 2) }

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        drop.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        publisher.send(2)

        XCTAssertEqual(tracking.history,
                       [.subscription("DropWhile"),
                        .completion(.failure(TestingError.oops))])
    }

    func testDemand() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.drop(while: { $0.isMultiple(of: 2) })
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                $0.request(.max(42))
                downstreamSubscription = $0
            },
            receiveValue: { _ in .max(4) }
        )

        drop.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)
        dump(type(of: downstreamSubscription!))

        XCTAssertEqual(subscription.history, [.requested(.max(1))])

        XCTAssertEqual(publisher.send(0), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(1))])

        XCTAssertEqual(publisher.send(2), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(1))])

        downstreamSubscription?.request(.max(95))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.max(1))])

        XCTAssertEqual(publisher.send(3), .max(145)) // 145 = 42 + 95 + 5 + 3
        XCTAssertEqual(subscription.history, [.requested(.max(1))])

        downstreamSubscription?.request(.max(121))
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .requested(.max(121))])

        XCTAssertEqual(publisher.send(7), .max(4))
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .requested(.max(121))])

        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .requested(.max(121)),
                                              .cancelled])
        downstreamSubscription?.request(.max(50))
        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .requested(.max(121)),
                                              .cancelled])

        XCTAssertEqual(publisher.send(8), .max(4))
    }

    func testTryDropWhileCancelsUpstreamOnThrow() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.tryDrop(while: { _ in throw "too much" as TestingError })
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in .max(42) }
        )

        drop.subscribe(tracking)
        XCTAssertEqual(subscription.history, [.requested(.max(1))])
        XCTAssertEqual(publisher.send(100), .none)
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .cancelled])
        publisher.send(completion: .finished)
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(tracking.history,
                       [.subscription("DropWhile"),
                        .completion(.failure("too much" as TestingError)),
                        .completion(.finished)])
    }

    func testDropWhileCompletion() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.drop(while: { _ in true })
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )

        drop.subscribe(tracking)
        XCTAssertEqual(subscription.history, [.requested(.max(1))])
        publisher.send(completion: .finished)
        publisher.send(completion: .finished)
        XCTAssertEqual(subscription.history, [.requested(.max(1))])
        XCTAssertEqual(tracking.history, [.subscription("DropWhile"),
                                          .completion(.finished),
                                          .completion(.finished)])
    }
}
