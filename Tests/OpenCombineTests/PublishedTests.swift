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
        testObject.$state.subscribe(tracking1)
        XCTAssertEqual(tracking1.history, [.subscription("CurrentValueSubject")])
        downstreamSubscription1?.request(.max(2))
        XCTAssertEqual(tracking1.history, [.subscription("CurrentValueSubject"),
                                          .value(0)])
        testObject.state += 1
        testObject.state += 2
        testObject.state += 3
        XCTAssertEqual(tracking1.history, [.subscription("CurrentValueSubject"),
                                          .value(0),
                                          .value(1)])
        downstreamSubscription1?.request(.max(10))
        XCTAssertEqual(tracking1.history, [.subscription("CurrentValueSubject"),
                                          .value(0),
                                          .value(1),
                                          .value(6)])

        let tracking2 = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        testObject.$state.subscribe(tracking2)
        XCTAssertEqual(tracking2.history, [.subscription("CurrentValueSubject"),
                                           .value(6)])

        testObject.state = 42
        XCTAssertEqual(tracking1.history, [.subscription("CurrentValueSubject"),
                                           .value(0),
                                           .value(1),
                                           .value(6),
                                           .value(42)])
        XCTAssertEqual(tracking2.history, [.subscription("CurrentValueSubject"),
                                           .value(6),
                                           .value(42)])

        downstreamSubscription1?.cancel()
        testObject.state = -1
        XCTAssertEqual(tracking1.history, [.subscription("CurrentValueSubject"),
                                           .value(0),
                                           .value(1),
                                           .value(6),
                                           .value(42)])
        XCTAssertEqual(tracking2.history, [.subscription("CurrentValueSubject"),
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
}

@available(macOS 10.15, iOS 13.0, *)
private final class TestObject: ObservableObject {

    let objectWillChange = ObservableObjectPublisher()

    @Published var state: Int

    init() {
        _state = Published(initialValue: 0)
    }
}

#endif
