//
//  SetFailureTypeTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.07.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class SetFailureTypeTests: XCTestCase {

    func testEmpty() {
        let tracking = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubjectBase<Int, Never>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "SetFailureType")
            }
        )

        publisher
            .setFailureType(to: Never.self)
            .setFailureType(to: TestingError.self)
            .subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject")])
    }

    func testForwardingValues() {
        let publisher = PassthroughSubject<Int, Never>()
        let sft = publisher.setFailureType(to: TestingError.self)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        publisher.send(1)
        sft.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(completion: .finished)
        publisher.send(5)

        XCTAssertEqual(tracking.history, [
            .subscription("PassthroughSubject"),
            .value(2),
            .value(3),
            .completion(.finished)
        ])
    }

    func testNoDemand() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)
        let sft = publisher.setFailureType(to: TestingError.self)
        let tracking = TrackingSubscriber()

        sft.subscribe(tracking)

        XCTAssert(subscription.history.isEmpty)
    }

    func testDemandSubscribe() {
        let expectedSubscribeDemand = 42
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)
        let sft = publisher.setFailureType(to: TestingError.self)

        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(expectedSubscribeDemand)) }
        )

        sft.subscribe(tracking)

        XCTAssertEqual(subscription.history, [.requested(.max(expectedSubscribeDemand))])
    }

    func testDemandSend() {

        var expectedReceiveValueDemand = 4
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)
        let sft = publisher.setFailureType(to: TestingError.self)
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in .max(expectedReceiveValueDemand) }
        )

        sft.subscribe(tracking)
        XCTAssertEqual(publisher.send(0), .max(4))

        expectedReceiveValueDemand = 120

        XCTAssertEqual(publisher.send(0), .max(120))
    }

    func testCompletion() {

        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)
        let sft = publisher.setFailureType(to: TestingError.self)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        sft.subscribe(tracking)
        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(
            tracking.history,
            [.subscription("CustomSubscription"), .completion(.finished)]
        )
    }

    func testCancel() throws {

        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)
        let sft = publisher.setFailureType(to: TestingError.self)

        var downstreamSubscription: Subscription?

        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })

        sft.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send(1), .none)
        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testCancelAlreadyCancelled() throws {

        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)
        let sft = publisher.setFailureType(to: TestingError.self)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })

        sft.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(downstreamSubscription).cancel()

        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled,
                                              .requested(.unlimited),
                                              .cancelled])
    }
}
