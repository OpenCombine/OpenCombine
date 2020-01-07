//
//  SwitchToLatestTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 07.01.2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class SwitchToLatestTests: XCTestCase {

    var cancellables = [AnyCancellable]()

    override func tearDown() {
        cancellables = []
        super.tearDown()
    }

    func testSwitchToLatestSequenceWithSink() {
        var history = [Int]()
        (1 ..< 5)
            .publisher
            .map {
                ($0 ..< $0 + 4).publisher
            }
            .switchToLatest()
            .sink {
                history.append($0)
            }.store(in: &cancellables)

        XCTAssertEqual(history, [1, 2, 3, 4, 2, 3, 4, 5, 3, 4, 5, 6, 4, 5, 6, 7])
    }

    func testCrashesWhenRequestedOneByOne() {
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: { _ in .max(1) }
        )
        tracking.store(in: &cancellables)

        assertCrashes {
            (1 ..< 5)
                .publisher
                .map {
                    ($0 ..< $0 + 4).publisher
                }
                .switchToLatest()
                .subscribe(tracking)
        }
    }

    func testSendsChildValuesFromLatestOuterPublisher() {
        let upstreamPublisher =
            PassthroughSubject<PassthroughSubject<Int, TestingError>, TestingError>()
        let childPublisher1 = PassthroughSubject<Int, TestingError>()
        let childPublisher2 = PassthroughSubject<Int, TestingError>()

        let switchToLatest = upstreamPublisher.switchToLatest()

        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
        })

        switchToLatest.subscribe(downstreamSubscriber)

        upstreamPublisher.send(childPublisher1)
        upstreamPublisher.send(childPublisher2)

        childPublisher1.send(666)
        childPublisher2.send(777)
        childPublisher1.send(888)
        childPublisher2.send(999)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("SwitchToLatest"),
                                                      .value(777),
                                                      .value(999)])
    }

    func testDemand() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .max(5),
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let subscription1 = CustomSubscription()
        let nestedPublisher1 = CustomPublisher(subscription: subscription1)
        XCTAssertEqual(helper.publisher.send(nestedPublisher1), .none)
        XCTAssertNotNil(nestedPublisher1.subscriber)
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(subscription1.history, [])

        try XCTUnwrap(helper.downstreamSubscription).request(.none)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1)) // demand == 1
        XCTAssertEqual(subscription1.history, [.requested(.none), .requested(.max(1))])

        nestedPublisher1.send(completion: .finished)

        try XCTUnwrap(helper.downstreamSubscription).request(.none)
        try XCTUnwrap(helper.downstreamSubscription).request(.max(41)) // demand == 42
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1)) // demand == 43

        XCTAssertEqual(subscription1.history, [.requested(.none), .requested(.max(1))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let subscription2 = CustomSubscription()
        let nestedPublisher2 = CustomPublisher(subscription: subscription2)

        XCTAssertEqual(helper.publisher.send(nestedPublisher2), .none)
        XCTAssertEqual(subscription1.history, [.requested(.max(0)), .requested(.max(1))])
        XCTAssertEqual(subscription2.history, [.requested(.max(43))])

        XCTAssertEqual(nestedPublisher2.send(1), .max(5)) // demand == 42
        XCTAssertEqual(nestedPublisher2.send(2), .max(5)) // demand == 41
        XCTAssertEqual(subscription2.history, [.requested(.max(43))])

        let subscription3 = CustomSubscription()
        let nestedPublisher3 = CustomPublisher(subscription: subscription3)

        XCTAssertEqual(helper.publisher.send(nestedPublisher3), .none)
        XCTAssertEqual(subscription2.history, [.requested(.max(43)), .cancelled])
        XCTAssertEqual(subscription3.history, [.requested(.max(41))])

        helper.publisher.send(completion: .finished)

        try XCTUnwrap(helper.downstreamSubscription).request(.max(9)) // demand == 50
        XCTAssertEqual(subscription3.history, [.requested(.max(41))])
    }

    func testCrashesWhenReceivingUnwantedValueFromNestedPublisher() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.switchToLatest() }
        )

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)
        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        assertCrashes {
            _ = nestedPublisher.send(-1)
        }
    }

    func testCancelCancels() throws {
        typealias NestedPublisher = CustomPublisherBase<Int, Never>
        let upstreamSubscription = CustomSubscription()
        let upstreamPublisher = CustomPublisherBase<NestedPublisher, Never>(
            subscription: upstreamSubscription
        )

        let childSubscription = CustomSubscription()
        let childPublisher = NestedPublisher(subscription: childSubscription)

        let switchToLatest = upstreamPublisher.switchToLatest()

        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                downstreamSubscription = $0
                $0.request(.max(42))
            }
        )

        upstreamSubscription.onCancel = {
            XCTAssertEqual(childSubscription.history, [.requested(.max(42)),
                                                       .cancelled])
        }

        childSubscription.onCancel = {
            XCTAssertEqual(upstreamSubscription.history, [.requested(.unlimited)])
        }

        switchToLatest.subscribe(tracking)

        XCTAssertEqual(upstreamPublisher.send(childPublisher), .none)

        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).cancel()

        XCTAssertEqual(upstreamSubscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(childSubscription.history, [.requested(.max(42)), .cancelled])
    }

    func testSwitchToLatestOuterReceiveSubscriptionTwice() throws {
        let subscription1 = CustomSubscription()
        let publisher =
            CustomPublisherBase<CustomPublisher, TestingError>(subscription: nil)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        tracking.store(in: &cancellables)
        publisher.switchToLatest().subscribe(tracking)

        XCTAssertEqual(tracking.history, [])

        publisher.send(subscription: subscription1)

        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])

        let subscription2 = CustomSubscription()
        publisher.send(subscription: subscription2)

        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])
        XCTAssertEqual(subscription2.history, [.cancelled])

        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(subscription1.history, [.requested(.unlimited), .cancelled])

        let subscription3 = CustomSubscription()
        publisher.send(subscription: subscription3)
        XCTAssertEqual(subscription3.history, [.cancelled])
    }

    func testSwitchToLatestInnerReceiveSubscriptionTwice() throws {
        let publisher = CustomPublisherBase<CustomPublisher, TestingError>(
            subscription: CustomSubscription()
        )
        let tracking = TrackingSubscriber()
        tracking.store(in: &cancellables)
        publisher.switchToLatest().subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest")])

        let subscription1 = CustomSubscription()
        let nestedPublisher1 = CustomPublisher(subscription: subscription1)
        XCTAssertEqual(publisher.send(nestedPublisher1), .none)

        XCTAssertEqual(subscription1.history, [])

        let subscription2 = CustomSubscription()
        nestedPublisher1.send(subscription: subscription2)

        XCTAssertEqual(subscription1.history, [])
        XCTAssertEqual(subscription2.history, [.cancelled])

        try XCTUnwrap(nestedPublisher1.erasedSubscriber as? Subscription).cancel()

        XCTAssertEqual(subscription1.history, [.cancelled])

        let subscription3 = CustomSubscription()
        nestedPublisher1.send(subscription: subscription3)
        XCTAssertEqual(subscription3.history, [])

        try XCTUnwrap(nestedPublisher1.erasedSubscriber as? Subscription).cancel()
        XCTAssertEqual(subscription3.history, [])

        let nestedPublisher2 = CustomPublisher(subscription: nil)

        var subscription4Destroyed = false
        do {
            let subscription4 = CustomSubscription(
                onDeinit: { subscription4Destroyed = true }
            )
            XCTAssertEqual(publisher.send(nestedPublisher2), .none)
            nestedPublisher2.send(subscription: subscription4)

            try XCTUnwrap(nestedPublisher2.subscriber).receive(completion: .finished)
            XCTAssertEqual(subscription4.history, [])
        }
        XCTAssert(subscription4Destroyed)

        let subscription5 = CustomSubscription()
        nestedPublisher2.send(subscription: subscription5)
        XCTAssertEqual(subscription5.history, [])

        try XCTUnwrap(nestedPublisher2.erasedSubscriber as? Subscription).cancel()
        XCTAssertEqual(subscription5.history, [])
    }

    func testSwitchToLatestOuterReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: CustomPublisherBase<Int, Never>(subscription: CustomSubscription()),
            expected: .history([], demand: .none),
            { $0.switchToLatest() }
        )
    }

    func testSwitchToLatestInnerReceiveValueBeforeSubscription() {
        let publisher = CustomPublisherBase<CustomPublisher, TestingError>(
            subscription: CustomSubscription()
        )
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) },
                                          receiveValue: { _ in .max(42) })
        tracking.store(in: &cancellables)
        publisher.switchToLatest().subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest")])

        let nestedPublisher = CustomPublisher(subscription: nil)
        XCTAssertEqual(publisher.send(nestedPublisher), .none)
        XCTAssertEqual(nestedPublisher.send(1), .max(42))
        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest"),
                                          .value(1)])
    }

    func testSwitchToLatestOuterReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: CustomPublisherBase<Int, Never>.self,
            expected: .history([]),
            { $0.switchToLatest() }
        )
    }

    func testSwitchToLatestInnerReceiveCompletionBeforeSubscription() {
        let publisher = CustomPublisherBase<CustomPublisher, TestingError>(
            subscription: CustomSubscription()
        )
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) },
                                          receiveValue: { _ in .max(42) })
        tracking.store(in: &cancellables)
        publisher.switchToLatest().subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest")])

        let nestedPublisher = CustomPublisher(subscription: nil)
        XCTAssertEqual(publisher.send(nestedPublisher), .none)
        nestedPublisher.send(completion: .finished)
        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest")])
    }

    func testSwitchToLatestInnerReceiveFailureBeforeSubscription() {
        let publisher = CustomPublisherBase<CustomPublisher, TestingError>(
            subscription: CustomSubscription()
        )
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) },
                                          receiveValue: { _ in .max(42) })
        tracking.store(in: &cancellables)
        publisher.switchToLatest().subscribe(tracking)
        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest")])

        let nestedPublisher = CustomPublisher(subscription: nil)
        XCTAssertEqual(publisher.send(nestedPublisher), .none)
        nestedPublisher.send(completion: .failure(.oops))
        XCTAssertEqual(tracking.history, [.subscription("SwitchToLatest"),
                                          .completion(.failure(.oops))])
    }

    func testOuterIgnoresInputAfterCancelling() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        XCTAssertEqual(nestedSubscription.history, [])
        XCTAssertNil(nestedPublisher.subscriber)
    }

    func testOuterIgnoresInputAfterFinishing() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .finished)

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        XCTAssertEqual(nestedSubscription.history, [])
        XCTAssertNil(nestedPublisher.subscriber)
    }

    func testInnerIgnoresInputAfterCancelling() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
        XCTAssertNotNil(nestedPublisher.subscriber)

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(nestedPublisher.send(1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
    }

    func testInnerIgnoresInputAfterOuterFinishes() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
        XCTAssertNotNil(nestedPublisher.subscriber)

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(nestedPublisher.send(1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
    }

    func testOuterIgnoresCompletionAfterCancelling() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
    }

    func testOuterReceiveCompletionTwice() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
    }

    func testInnerIgnoresCompletionAfterCancelling() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
        XCTAssertNotNil(nestedPublisher.subscriber)

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        nestedPublisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
    }

    func testInnerIgnoresEventsAfterOuterFails() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
        XCTAssertNotNil(nestedPublisher.subscriber)

        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1)), .cancelled])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(nestedPublisher.send(1), .none)
        nestedPublisher.send(completion: .finished)
        nestedPublisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest"),
                                                 .completion(.failure(.oops))])
    }

    func testInnerIgnoresEventsAfterOuterFinishes() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
        XCTAssertNotNil(nestedPublisher.subscriber)

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(nestedPublisher.send(1), .none)
        nestedPublisher.send(completion: .finished)
        nestedPublisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
    }

    func testOuterFinishesThenInnerFinishes() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])

        nestedPublisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
    }

    func testInnerFinishesThenOuterFinishes() {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<CustomPublisher, TestingError>.self,
            initialDemand: .max(1),
            receiveValueDemand: .max(100),
            createSut: { $0.switchToLatest() }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        let nestedSubscription = CustomSubscription()
        let nestedPublisher = CustomPublisher(subscription: nestedSubscription)

        XCTAssertEqual(helper.publisher.send(nestedPublisher), .none)
        nestedPublisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("SwitchToLatest"),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(nestedSubscription.history, [.requested(.max(1))])
    }

    func testSwitchToLatestLifecycle() throws {
        try testLifecycle(sendValue: CustomPublisher(subscription: CustomSubscription()),
                          cancellingSubscriptionReleasesSubscriber: true,
                          { $0.switchToLatest() })
    }

    func testSwitchToLatestReflection() {
        let publisher = CustomPublisherBase<CustomPublisher, TestingError>(
            subscription: CustomSubscription()
        )
        let tracking = TrackingSubscriber()
        tracking.store(in: &cancellables)
        publisher.switchToLatest().subscribe(tracking)
        XCTAssert(publisher.erasedSubscriber is Subscription)

        guard let outer = publisher.erasedSubscriber,
              let routingSubscription = tracking.subscriptions.first?.underlying else {
            XCTFail("Missing subscriber/subscription")
            return
        }

        XCTAssert(type(of: outer) != type(of: routingSubscription),
                  "outer and routingSubscription must be of different types")

        XCTAssertEqual(routingSubscription.combineIdentifier,
                       (outer as? Subscription)?.combineIdentifier)

        func testReflections(_ subject: Any,
                             file: StaticString = #file,
                             line: UInt = #line) {
            XCTAssertEqual((subject as? CustomStringConvertible)?.description,
                           "SwitchToLatest",
                           file: file,
                           line: line)
            XCTAssertFalse(subject is CustomDebugStringConvertible,
                           file: file,
                           line: line)
            XCTAssertEqual(
                (subject as? CustomPlaygroundDisplayConvertible)?
                    .playgroundDescription as? String,
                "SwitchToLatest",
                file: file,
                line: line
            )
            if let mirror = (subject as? CustomReflectable)?.customMirror {
                XCTAssert(childrenIsEmpty(mirror),
                          file: file,
                          line: line)
            } else {
                XCTFail("subject should conform to CustomReflectable",
                        file: file,
                        line: line)
            }
        }

        testReflections(outer)
        testReflections(routingSubscription)

        let nestedPublisher = CustomPublisher(subscription: CustomSubscription())
        _ = publisher.send(nestedPublisher)
        guard let innerLatest = nestedPublisher.erasedSubscriber else {
            XCTFail("Missing InnerLatest")
            return
        }

        XCTAssert(innerLatest is Subscription)
        XCTAssert(type(of: innerLatest) != type(of: outer))
        XCTAssert(type(of: innerLatest) != type(of: routingSubscription))
        testReflections(innerLatest)
    }
}
