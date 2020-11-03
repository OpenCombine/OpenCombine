//
//  PublishedTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 08/09/2019.
//

import XCTest

#if swift(>=5.1)

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine

@available(macOS 10.15, iOS 13.0, *)
private typealias Published = Combine.Published

@available(macOS 10.15, iOS 13.0, *)
private typealias ObservableObject = Combine.ObservableObject
#else
import OpenCombine

private typealias Published = OpenCombine.Published

private typealias ObservableObject = OpenCombine.ObservableObject
#endif

@available(macOS 10.15, iOS 13.0, *)
final class PublishedTests: XCTestCase {

    func testBasicBehavior() {
        let testObject = TestObject()
        var downstreamSubscription1: Subscription?
        let tracking1 = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { downstreamSubscription1 = $0 }
        )

        var currentValue = 0
        tracking1.onValue = { _ in
            XCTAssertEqual(
                testObject.state,
                currentValue,
                "Value of @Published should be updated _after_ sending it downstream"
            )
        }

        testObject.$state.subscribe(tracking1)
        XCTAssertEqual(tracking1.history, [.subscription("PublishedSubject")])
        downstreamSubscription1?.request(.max(2))
        XCTAssertEqual(tracking1.history, [.subscription("PublishedSubject"),
                                          .value(0)])
        testObject.state += 1
        currentValue = 1
        testObject.state += 2
        currentValue = 3
        testObject.state += 3
        currentValue = 6
        XCTAssertEqual(tracking1.history, [.subscription("PublishedSubject"),
                                          .value(0),
                                          .value(1)])
        downstreamSubscription1?.request(.max(10))
        XCTAssertEqual(tracking1.history, [.subscription("PublishedSubject"),
                                          .value(0),
                                          .value(1),
                                          .value(6)])

        let tracking2 = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        testObject.$state.subscribe(tracking2)
        XCTAssertEqual(tracking2.history, [.subscription("PublishedSubject"),
                                           .value(6)])

        testObject.state = 42
        currentValue = 42
        XCTAssertEqual(tracking1.history, [.subscription("PublishedSubject"),
                                           .value(0),
                                           .value(1),
                                           .value(6),
                                           .value(42)])
        XCTAssertEqual(tracking2.history, [.subscription("PublishedSubject"),
                                           .value(6),
                                           .value(42)])

        downstreamSubscription1?.cancel()
        testObject.state = -1

        XCTAssertEqual(tracking1.history, [.subscription("PublishedSubject"),
                                           .value(0),
                                           .value(1),
                                           .value(6),
                                           .value(42)])
        XCTAssertEqual(tracking2.history, [.subscription("PublishedSubject"),
                                           .value(6),
                                           .value(42),
                                           .value(-1)])
    }

    func testObservableObjectWithCustomObjectWillChange() {
        let testObject = TestObject()
        var downstreamSubscription: Subscription?
        let tracking1 = TrackingSubscriberBase<Void, Never>(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        testObject.objectWillChange.subscribe(tracking1)
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher")])
        downstreamSubscription?.request(.max(2))
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher")])
        testObject.state = 100
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher")])
    }

    @available(macOS 11.0, iOS 14.0, *)
    func testAssignToPublished() throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)
        let tracking = TrackingSubscriberBase<Int, Never>()

        do {
            let testObject = TestObject()
            publisher.assign(to: &testObject.$state)
            XCTAssertEqual(subscription.history, [.requested(.unlimited)])

            testObject.$state.subscribe(tracking)
            XCTAssertEqual(subscription.history, [.requested(.unlimited)])
            XCTAssertEqual(tracking.history, [.subscription("PublishedSubject")])

            XCTAssertEqual(publisher.send(1), .none)
            XCTAssertEqual(subscription.history, [.requested(.unlimited)])
            XCTAssertEqual(tracking.history, [.subscription("PublishedSubject")])

            try XCTUnwrap(tracking.subscriptions.first).request(.max(3))

            XCTAssertEqual(publisher.send(2), .none)
            XCTAssertEqual(publisher.send(3), .none)
            XCTAssertEqual(publisher.send(4), .none)
            XCTAssertEqual(subscription.history, [.requested(.unlimited)])
            XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                              .value(1),
                                              .value(2),
                                              .value(3)])

            tracking.cancel()

            XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        }

        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled])
    }

    @available(macOS 11.0, iOS 14.0, *)
    func testAssignToPublishedFinish() {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)
        let tracking = TrackingSubscriberBase<Int, Never>()

        let testObject = TestObject()
        publisher.assign(to: &testObject.$state)
        testObject.$state.subscribe(tracking)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject")])

        publisher.send(completion: .finished)

        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject")])
    }

    func testPublishedSubjectDemand() throws {
        let testObject = TestObject()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { downstreamSubscription = $0 },
            receiveValue: { .max($0) }
        )

        testObject.$state.subscribe(tracking)

        try XCTUnwrap(downstreamSubscription).request(.max(2))
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                          .value(0)])
        // demand = 1

        testObject.state = 1
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                          .value(0),
                                          .value(1)])
        // demand = 1 - 1 + 1 = 1

        testObject.state = 2
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                          .value(0),
                                          .value(1),
                                          .value(2)])
        // demand = 1 - 1 + 2 = 2

        testObject.state = 0
        testObject.state = 0
        testObject.state = 0
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(0),
                                          .value(0)])
        // demand = 2 - 2 = 0, value pending

        try XCTUnwrap(downstreamSubscription).request(.max(2))
        try XCTUnwrap(downstreamSubscription).request(.max(3))
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(0),
                                          .value(0),
                                          .value(0)])
        // demand = 0 + 2 + 3 - 1 = 4

        testObject.state = 0
        testObject.state = 0
        testObject.state = 0
        testObject.state = 0
        testObject.state = 1
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(0)])
        // demand = 4 - 4 = 0, value pending

        try XCTUnwrap(downstreamSubscription).request(.max(1))
        testObject.state = 0
        testObject.state = 0
        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(0),
                                          .value(1),
                                          .value(0)])
        // demand = 0
    }

    func testPublishedSubjectCancelAlreadyCancelled() throws {
        let testObject = TestObject()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { downstreamSubscription = $0 },
            receiveValue: { _ in .max(1) }
        )

        testObject.$state.subscribe(tracking)

        try XCTUnwrap(downstreamSubscription).request(.max(1))
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).request(.max(100))
        try XCTUnwrap(downstreamSubscription).cancel()

        testObject.state = 42

        XCTAssertEqual(tracking.history, [.subscription("PublishedSubject"),
                                          .value(0)])
    }

    func testPublishedSubjectConduitReflection() throws {
        let testObject = TestObject()
        try testSubscriptionReflection(
            description: "PublishedSubject",
            customMirror: expectedChildren(
                ("parent", .contains("PublishedSubject")),
                ("downstream", .contains("TrackingSubscriberBase")),
                ("demand", "max(0)"),
                ("subject", .contains("PublishedSubject"))
            ),
            playgroundDescription: "PublishedSubject",
            sut: testObject.$state
        )
    }

    @available(macOS 11.0, iOS 14.0, *)
    func testProjectedValueSetter() {
        let testObject1 = TestObject(1)
        let testObject2 = TestObject(2)

        XCTAssertEqual(testObject1.state, 1)
        XCTAssertEqual(testObject2.state, 2)

        testObject1.$state = testObject2.$state

        XCTAssertEqual(testObject1.state, 1)
        XCTAssertEqual(testObject2.state, 2)

        testObject1.$state = testObject2.$state

        XCTAssertEqual(testObject1.state, 1)
        XCTAssertEqual(testObject2.state, 2)
    }
}

@available(macOS 10.15, iOS 13.0, *)
private final class TestObject: ObservableObject {

    let objectWillChange = ObservableObjectPublisher()

    @Published var state: Int

    init(_ initialValue: Int = 0) {
        _state = Published(initialValue: initialValue)
    }
}

#endif
