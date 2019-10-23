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

@available(macOS 10.15, iOS 13.0, *)
final class DropWhileTests: XCTestCase {

    // MARK: - DropWhile

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

        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        XCTAssertEqual(publisher.send(0), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        XCTAssertEqual(publisher.send(2), .max(1))
        XCTAssertEqual(subscription.history, [.requested(.max(42))])

        downstreamSubscription?.request(.max(95))
        downstreamSubscription?.request(.max(5))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5))])

        XCTAssertEqual(publisher.send(3), .max(4))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5))])

        downstreamSubscription?.request(.max(121))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .requested(.max(121))])

        XCTAssertEqual(publisher.send(7), .max(4))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .requested(.max(121))])

        downstreamSubscription?.cancel()
        downstreamSubscription?.cancel()
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .requested(.max(121)),
                                              .cancelled])

        downstreamSubscription?.request(.max(50))
        XCTAssertEqual(subscription.history, [.requested(.max(42)),
                                              .requested(.max(95)),
                                              .requested(.max(5)),
                                              .requested(.max(121)),
                                              .cancelled])

        XCTAssertEqual(publisher.send(8), .none)
    }

    func testDropWhileCompletion() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let drop = publisher.drop(while: { _ in true })
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) }
        )

        drop.subscribe(tracking)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        publisher.send(completion: .finished)
        publisher.send(completion: .finished)
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("DropWhile"),
                                          .completion(.finished)])

        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("DropWhile"),
                                          .completion(.finished)])
    }

    func testCancelAlreadyCancelled() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let dropWhile = publisher.drop(while: { _ in true })
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })

        dropWhile.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(downstreamSubscription).cancel()

        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])

        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(tracking.history, [.subscription("DropWhile")])
    }

    func testDropWhileLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.drop(while: { _ in false }) })
    }

    func testDropWhileReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "DropWhile",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "DropWhile",
                           { $0.drop(while: { $0 < 2 }) })
    }

    // MARK: - TryDropWhile

    func testTryDropWhileFailureBecauseOfThrow() {
        var counter = 0 // How many times the predicate is called?

        let predicate: (Int) throws -> Bool = {
            counter += 1
            if $0 == 100 {
                throw "too much" as TestingError
            }
            return $0.isMultiple(of: 2)
        }

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.tryDrop(while: predicate) })

        XCTAssertEqual(helper.tracking.history, [.subscription("TryDropWhile")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(4), .max(1))
        XCTAssertEqual(helper.publisher.send(100), .none)
        XCTAssertEqual(helper.publisher.send(9), .none)
        XCTAssertEqual(helper.publisher.send(8), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure("too much" as TestingError))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure("too much" as TestingError))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])

        XCTAssertEqual(counter, 3)
    }

    func testTryDropWhileFailureOnCompletion() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: { $0.tryDrop { $0.isMultiple(of: 2) } }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("TryDropWhile")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testTryDropWhileSuccess() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .none,
            createSut: { $0.tryDrop { $0.isMultiple(of: 2) } }
        )

        XCTAssertEqual(helper.publisher.send(0), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(5), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .value(3),
                        .value(4),
                        .value(5)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.publisher.send(8), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryDropWhile"),
                        .value(3),
                        .value(4),
                        .value(5),
                        .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
    }

    func testTryDropWhileLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryDrop(while: { _ in false }) })
    }

    func testTryDropWhileReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "TryDropWhile",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "TryDropWhile",
                           { $0.tryDrop(while: { $0 < 2 }) })
    }
}
