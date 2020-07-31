//
//  MeasureIntervalTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MeasureIntervalTests: XCTestCase {

    func testBasicBehavior() {
        let scheduler = VirtualTimeScheduler()
        scheduler.rewind(to: .nanoseconds(3))
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(13),
                                        receiveValueDemand: .none) {
            $0.measureInterval(using: scheduler, options: .nontrivialOptions)
        }
        XCTAssertEqual(helper.tracking.history, [.subscription("MeasureInterval")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(13))])
        XCTAssertEqual(scheduler.history, [.now])

        scheduler.rewind(to: .nanoseconds(14))
        XCTAssertEqual(helper.publisher.send(1), .none)
        scheduler.rewind(to: .nanoseconds(17))
        XCTAssertEqual(helper.publisher.send(2), .none)
        scheduler.rewind(to: .nanoseconds(10))
        XCTAssertEqual(helper.publisher.send(3), .none)
        scheduler.rewind(to: .nanoseconds(21))
        XCTAssertEqual(helper.publisher.send(4), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("MeasureInterval"),
                                                 .value(.nanoseconds(11)),
                                                 .value(.nanoseconds(3)),
                                                 .value(.nanoseconds(-7)),
                                                 .value(.nanoseconds(11)),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(13))])
        XCTAssertEqual(scheduler.history, [.now, .now, .now, .now, .now])
    }

    func testRequest() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1)) {
            $0.measureInterval(using: scheduler, options: .nontrivialOptions)
        }

        var recursionCounter = 5
        helper.subscription.onRequest = { _ in
            if recursionCounter == 0 { return }
            recursionCounter -= 1
            XCTAssertEqual(helper.publisher.send(0), .none)
        }

        XCTAssertEqual(helper.publisher.send(0), .none)

        helper.subscription.onRequest = nil

        try XCTUnwrap(helper.downstreamSubscription).request(.max(2))
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).request(.none)

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("MeasureInterval"),
                                                 .value(.zero),
                                                 .value(.zero),
                                                 .value(.zero),
                                                 .value(.zero),
                                                 .value(.zero),
                                                 .value(.zero),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(1)),
                                                     .requested(.max(2)),
                                                     .requested(.unlimited),
                                                     .requested(.none)])
    }

    func testCancelAlreadyCancelled() throws {
        let scheduler = VirtualTimeScheduler()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1)) {
            $0.measureInterval(using: scheduler, options: .nontrivialOptions)
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("MeasureInterval")])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(scheduler.history, [.now])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1000))
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send(1000), .none)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("MeasureInterval")])
        XCTAssertEqual(helper.subscription.history, [.cancelled])
        XCTAssertEqual(scheduler.history, [.now])
    }

    func testMeasureIntervalReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice {
            $0.measureInterval(using: ImmediateScheduler.shared)
        }
    }

    func testMeasureIntervalReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 213,
                                           expected: .history([], demand: .none)) {
            $0.measureInterval(using: ImmediateScheduler.shared)
        }
    }

    func testMeasureIntervalReceiveCompletionBeforeSubscription()  {
        testReceiveCompletionBeforeSubscription(inputType: Int.self,
                                                expected: .history([])) {
            $0.measureInterval(using: ImmediateScheduler.shared)
        }
    }

    func testMeasureIntervalRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.measureInterval(using: ImmediateScheduler.shared)
        }
    }

    func testMeasureIntervalCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self, shouldCrash: false) {
            $0.measureInterval(using: ImmediateScheduler.shared)
        }
    }

    func testMeasureIntervalReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "MeasureInterval",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "MeasureInterval",
                           { $0.measureInterval(using: ImmediateScheduler.shared) })
    }

    func testMeasureIntervalLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.measureInterval(using: ImmediateScheduler.shared) })
    }
}
