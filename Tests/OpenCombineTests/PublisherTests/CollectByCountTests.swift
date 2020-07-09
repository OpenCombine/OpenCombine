//
//  CollectByCountTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CollectByCountTests: XCTestCase {

    func testBasicBehavior() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(2),
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.collect(4) })

        XCTAssertEqual(helper.subscription.history, [.requested(.max(8))])
        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount")])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount")])

        XCTAssertEqual(helper.publisher.send(4), .max(12))

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount"),
                                                 .value([1, 2, 3, 4])])

        XCTAssertEqual(helper.publisher.send(5), .none)
        XCTAssertEqual(helper.publisher.send(6), .none)
        XCTAssertEqual(helper.publisher.send(7), .none)
        XCTAssertEqual(helper.publisher.send(8), .max(12))
        XCTAssertEqual(helper.publisher.send(9), .none)
        XCTAssertEqual(helper.publisher.send(10), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount"),
                                                 .value([1, 2, 3, 4]),
                                                 .value([5, 6, 7, 8])])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount"),
                                                 .value([1, 2, 3, 4]),
                                                 .value([5, 6, 7, 8]),
                                                 .value([9, 10]),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(8))])
    }

    func testFinishWithEmptyBuffer() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.collect(4) })
        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .max(12))
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(5), .none)
        XCTAssertEqual(helper.publisher.send(6), .none)
        XCTAssertEqual(helper.publisher.send(7), .none)
        XCTAssertEqual(helper.publisher.send(8), .none)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(2))

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount"),
                                                 .value([1, 2, 3, 4]),
                                                 .completion(.finished),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testFailureWithEmptyBuffer() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.collect(4) })
        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .max(12))
        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(5), .none)
        XCTAssertEqual(helper.publisher.send(6), .none)
        XCTAssertEqual(helper.publisher.send(7), .none)
        XCTAssertEqual(helper.publisher.send(8), .none)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(2))

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount"),
                                                 .value([1, 2, 3, 4]),
                                                 .completion(.failure(.oops)),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testFailureWithNonEmptyBuffer() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.collect(4) })
        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(5), .none)
        XCTAssertEqual(helper.publisher.send(6), .none)
        XCTAssertEqual(helper.publisher.send(7), .none)
        XCTAssertEqual(helper.publisher.send(8), .none)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(2))

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount"),
                                                 .completion(.failure(.oops)),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
    }

    func testCrashesOnZeroDemand() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.collect(4) })

        try assertCrashes {
            try XCTUnwrap(helper.downstreamSubscription).request(.none)
        }
    }

    func testCancelThenFinish() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.collect(4) })

        XCTAssertEqual(helper.publisher.send(1), .none)
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount"),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.collect(4) })

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        let subscription2 = CustomSubscription()
        helper.publisher.send(subscription: subscription2)
        XCTAssertEqual(subscription2.history, [.cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(2))
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("CollectByCount"),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])
    }

    func testCollectByCountReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 42,
                                           expected: .history([], demand: .none),
                                           { $0.collect(19) })
    }

    func testCollectByCountReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.collect(19) }
        )
    }

    func testCollectByCountRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.collect(19) })
    }

    func testCollectByCountCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.collect(19) })
    }

    func testCollectByCountReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.collect(19) }
    }

    func testCollectByCountLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.collect(42) })
    }

    func testCollectByCountReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "CollectByCount",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("upstreamSubscription", .anything),
                               ("buffer", "[]"),
                               ("count", "53")
                           ),
                           playgroundDescription: "CollectByCount",
                           { $0.collect(53) })
    }
}
