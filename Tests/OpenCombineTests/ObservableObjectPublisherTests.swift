//
//  ObservableObjectPublisherTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 26.11.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ObservableObjectPublisherTests: XCTestCase {

    func testBasicBehavior() {
        let publisher = ObservableObjectPublisher()
        var downstreamSubscription1: Subscription?
        let tracking1 = TrackingSubscriberBase<Void, Never>(
            receiveSubscription: { downstreamSubscription1 = $0 }
        )
        publisher.subscribe(tracking1)
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher")])
        downstreamSubscription1?.request(.max(1))
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher")])
        publisher.send()
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal])
        publisher.send()
        publisher.send()
        downstreamSubscription1?.request(.max(3))
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal])
        publisher.send()
        publisher.send()
        publisher.send()
        publisher.send()
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        downstreamSubscription1?.request(.unlimited)

        let tracking2 = TrackingSubscriberBase<Void, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        publisher.subscribe(tracking2)
        tracking2.assertHistoryEqual([.subscription("ObservableObjectPublisher")])

        publisher.send()
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        tracking2.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal])

        downstreamSubscription1?.cancel()
        publisher.send()
        tracking1.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        tracking2.assertHistoryEqual([.subscription("ObservableObjectPublisher"),
                                      .signal,
                                      .signal])

        tracking1.cancel()
        tracking2.cancel()
    }

    func testObservableObjectPublisherReflection() throws {
        try testSubscriptionReflection(
            description: "ObservableObjectPublisher",
            customMirror: expectedChildren(
                ("downstream", .contains("TrackingSubscriberBase"))
            ),
            playgroundDescription: "ObservableObjectPublisher",
            sut: ObservableObjectPublisher()
        )
    }
}
