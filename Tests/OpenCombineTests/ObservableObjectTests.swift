//
//  ObservableObjectTests.swift
//
//
//  Created by kateinoigakukun on 2020/12/22.
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
final class ObservableObjectTests: XCTestCase {

    func testBasicBehavior() {
        let testObject = TestObject()
        var downstreamSubscription1: Subscription?
        let tracking1 = TrackingSubscriberBase<Void, Never>(
            receiveSubscription: { downstreamSubscription1 = $0 }
        )

        testObject.objectWillChange.subscribe(tracking1)
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher")])
        downstreamSubscription1?.request(.max(2))
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher")])
        testObject.state1 += 1
        testObject.state1 += 2
        testObject.state1 += 3
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal])
        testObject.state2 += 1
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        downstreamSubscription1?.request(.max(10))
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])

        let tracking2 = TrackingSubscriberBase<Void, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        testObject.objectWillChange.subscribe(tracking2)
        tracking2.assertHistoryEqual([.subscription("ObservableObjectPublisher")])

        testObject.state1 = 42
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        tracking2.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal])

        downstreamSubscription1?.cancel()
        testObject.state1 = -1

        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        tracking2.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .value(()),
                                      .value(())])
    }
}

@available(macOS 10.15, iOS 13.0, *)
private final class TestObject: ObservableObject {
    @Published var state1: Int
    @Published var state2: Int
    var nonPublished: Int

    init(_ initialValue: Int = 0) {
        _state1 = Published(initialValue: initialValue)
        _state2 = Published(initialValue: initialValue)
        nonPublished = initialValue
    }
}

#endif
