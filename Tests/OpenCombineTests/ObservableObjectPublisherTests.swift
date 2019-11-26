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

@available(macOS 10.15, iOS 13.0, *)
final class ObservableObjectPublisherTests: XCTestCase {

    func testBasicBehavior() {
        let publisher = ObservableObjectPublisher()
        var downstreamSubscription1: Subscription?
        let tracking1 = TrackingSubscriberBase<Void, Never>(
            receiveSubscription: { downstreamSubscription1 = $0 }
        )
        publisher.subscribe(tracking1)
        tracking1.assertHistoryEqual([.subscription("PassthroughSubject")])
        downstreamSubscription1?.request(.max(1))
        tracking1.assertHistoryEqual([.subscription("PassthroughSubject")])
        publisher.send()
        tracking1.assertHistoryEqual([.subscription("PassthroughSubject"),
                                      .signal])
        publisher.send()
        publisher.send()
        downstreamSubscription1?.request(.max(3))
        tracking1.assertHistoryEqual([.subscription("PassthroughSubject"),
                                      .signal])
        publisher.send()
        publisher.send()
        publisher.send()
        publisher.send()
        tracking1.assertHistoryEqual([.subscription("PassthroughSubject"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        downstreamSubscription1?.request(.unlimited)

        let tracking2 = TrackingSubscriberBase<Void, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        publisher.subscribe(tracking2)
        tracking2.assertHistoryEqual([.subscription("PassthroughSubject")])

        publisher.send()
        tracking1.assertHistoryEqual([.subscription("PassthroughSubject"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        tracking2.assertHistoryEqual([.subscription("PassthroughSubject"),
                                      .signal])

        downstreamSubscription1?.cancel()
        publisher.send()
        tracking1.assertHistoryEqual([.subscription("PassthroughSubject"),
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal,
                                      .signal])
        tracking2.assertHistoryEqual([.subscription("PassthroughSubject"),
                                      .signal,
                                      .signal])
    }
}
