//
//  HandleEventsTests.swift
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
final class HandleEventsTests: XCTestCase {

    func testBasicBehavior() throws {
        var history = [Event<TestingError>]()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let handleEvents = publisher.handleAllEvents { history.append($0) }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                XCTAssertNotNil(publisher.subscriber)
                downstreamSubscription = $0
            },
            receiveValue: { .max($0) }
        )
        handleEvents.subscribe(tracking)

        XCTAssertNotNil(publisher.subscriber)
        XCTAssertEqual(tracking.history, [.subscription("HandleEvents")])
        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(history, [.receiveSubscription("CustomSubscription")])

        XCTAssertEqual(publisher.send(0), .none)
        XCTAssertEqual(publisher.send(1), .max(1))
        XCTAssertEqual(publisher.send(2), .max(2))
        XCTAssertEqual(publisher.send(3), .max(3))

        XCTAssertEqual(tracking.history, [.subscription("HandleEvents"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(3)])
        XCTAssertEqual(subscription.history, [])
        XCTAssertEqual(history, [.receiveSubscription("CustomSubscription"),
                                 .receiveOutput(0),
                                 .receiveOutput(1),
                                 .receiveRequest(.max(1)),
                                 .receiveOutput(2),
                                 .receiveRequest(.max(2)),
                                 .receiveOutput(3),
                                 .receiveRequest(.max(3))])

        try XCTUnwrap(downstreamSubscription).request(.max(14))
        try XCTUnwrap(downstreamSubscription).request(.max(10))
        try XCTUnwrap(downstreamSubscription).request(.none)

        XCTAssertEqual(tracking.history, [.subscription("HandleEvents"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(3)])
        XCTAssertEqual(subscription.history, [.requested(.max(14)),
                                              .requested(.max(10)),
                                              .requested(.none)])
        XCTAssertEqual(history, [.receiveSubscription("CustomSubscription"),
                                 .receiveOutput(0),
                                 .receiveOutput(1),
                                 .receiveRequest(.max(1)),
                                 .receiveOutput(2),
                                 .receiveRequest(.max(2)),
                                 .receiveOutput(3),
                                 .receiveRequest(.max(3)),
                                 .receiveRequest(.max(14)),
                                 .receiveRequest(.max(10)),
                                 .receiveRequest(.none)])

        publisher.send(completion: .finished)
        publisher.send(completion: .failure(.oops))
        publisher.send(completion: .finished)
        XCTAssertEqual(publisher.send(144), .max(144))

        XCTAssertEqual(tracking.history, [.subscription("HandleEvents"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .completion(.finished),
                                          .completion(.failure(.oops)),
                                          .completion(.finished),
                                          .value(144)])
        XCTAssertEqual(subscription.history, [.requested(.max(14)),
                                              .requested(.max(10)),
                                              .requested(.none)])
        XCTAssertEqual(history, [.receiveSubscription("CustomSubscription"),
                                 .receiveOutput(0),
                                 .receiveOutput(1),
                                 .receiveRequest(.max(1)),
                                 .receiveOutput(2),
                                 .receiveRequest(.max(2)),
                                 .receiveOutput(3),
                                 .receiveRequest(.max(3)),
                                 .receiveRequest(.max(14)),
                                 .receiveRequest(.max(10)),
                                 .receiveRequest(.none),
                                 .receiveCompletion(.finished)])
    }

    func testAccumulatesDemandUntilSubscriptionArrives() {
        var history = [Event<TestingError>]()
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let handleEvents = publisher.handleAllEvents { history.append($0) }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                XCTAssertNotNil(publisher.subscriber)
                XCTAssertEqual(history, [.receiveSubscription("CustomSubscription")])
                XCTAssertEqual(subscription.history, [])
                $0.request(.max(45))
                $0.request(.none)
                $0.request(.max(13))
                XCTAssertEqual(subscription.history, [.requested(.max(45)),
                                                      .requested(.none),
                                                      .requested(.max(13))])
                downstreamSubscription = $0
            },
            receiveValue: { .max($0) }
        )
        handleEvents.subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("HandleEvents")])
        XCTAssertEqual(subscription.history, [.requested(.max(45)),
                                              .requested(.none),
                                              .requested(.max(13))])
        XCTAssertEqual(history, [.receiveSubscription("CustomSubscription"),
                                 .receiveRequest(.max(45)),
                                 .receiveRequest(.none),
                                 .receiveRequest(.max(13))])
        XCTAssertNotNil(downstreamSubscription)
    }

    func testCancelAlreadyCancelled() throws {
        var history = [Event<TestingError>]()
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(2),
                                        receiveValueDemand: .max(5)) {
            $0.handleAllEvents { history.append($0) }
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("HandleEvents")])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
        XCTAssertEqual(history, [.receiveSubscription("CustomSubscription"),
                                 .receiveRequest(.max(2))])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.publisher.send(1), .max(5))
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("HandleEvents"),
                                                 .value(1),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(2)),
                                                     .cancelled])
        XCTAssertEqual(history, [.receiveSubscription("CustomSubscription"),
                                 .receiveRequest(.max(2)),
                                 .receiveCancel])
    }

    func testHandleEventsReceiveSubscriptionTwice() throws {
        var history = [Event<TestingError>]()
        try testReceiveSubscriptionTwice { $0.handleAllEvents { history.append($0) } }
        XCTAssertEqual(history, [.receiveSubscription("CustomSubscription"),
                                 .receiveSubscription("CustomSubscription"),
                                 .receiveSubscription("CustomSubscription"),
                                 .receiveCancel])
    }

    func testHandleEventsReceiveValueBeforeSubscription() {
        var history = [Event<Never>]()
        testReceiveValueBeforeSubscription(
            value: 144,
            expected: .history([.value(144)],
                               demand: .max(42)),
            { $0.handleAllEvents { history.append($0) } }
        )
        XCTAssertEqual(history, [.receiveOutput(144),
                                 .receiveRequest(.max(42))])
    }

    func testHandleEventsReceiveCompletionBeforeSubscription() {
        var history = [Event<Never>]()
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.handleAllEvents { history.append($0) } }
        )
        XCTAssertEqual(history, [.receiveCompletion(.finished)])
    }

    func testHandleEventsRequestBeforeSubscription() {
        var history = [Event<Never>]()
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.handleAllEvents { history.append($0) } })
        XCTAssertEqual(history, [.receiveRequest(.max(1))])
    }

    func testHandleEventsCancelBeforeSubscription() {
        var history = [Event<Never>]()
        testCancelBeforeSubscription(inputType: Int.self,
                                     shouldCrash: false,
                                     { $0.handleAllEvents { history.append($0) } })
        XCTAssertEqual(history, [.receiveCancel])
    }

    func testHandleEventsReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "HandleEvents",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "HandleEvents",
                           { $0.handleEvents() })
    }

    func testHandleEventsLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.handleEvents() })
    }
}

@available(macOS 10.15, iOS 13.0, *)
private enum Event<Failure: Error & Equatable>: Equatable {
    case receiveSubscription(StringSubscription)
    case receiveOutput(Int)
    case receiveCompletion(Subscribers.Completion<Failure>)
    case receiveCancel
    case receiveRequest(Subscribers.Demand)
}

@available(macOS 10.15, iOS 13.0, *)
extension Publisher where Output == Int, Failure: Equatable {
    fileprivate func handleAllEvents(
        _ handle: @escaping (Event<Failure>) -> Void
    ) -> Publishers.HandleEvents<Self> {
        return handleEvents(
            receiveSubscription: { handle(.receiveSubscription(.subscription($0))) },
            receiveOutput: { handle(.receiveOutput($0)) },
            receiveCompletion: { handle(.receiveCompletion($0)) },
            receiveCancel: { handle(.receiveCancel) },
            receiveRequest: { handle(.receiveRequest($0)) }
        )
    }
}
