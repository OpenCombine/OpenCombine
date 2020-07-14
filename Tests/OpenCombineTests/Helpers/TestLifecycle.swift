//
//  TestLifecycle.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
func testLifecycle<UpstreamOutput, Operator: Publisher>(
    file: StaticString = #file,
    line: UInt = #line,
    sendValue valueToBeSent: UpstreamOutput,
    cancellingSubscriptionReleasesSubscriber: Bool,
    finishingIsPassedThrough: Bool = true,
    _ makeOperator: (PassthroughSubject<UpstreamOutput, TestingError>) -> Operator
) throws {
    var deinitCounter = 0

    let onDeinit = { deinitCounter += 1 }

    // Lifecycle test #1
    do {
        let passthrough = PassthroughSubject<UpstreamOutput, TestingError>()
        let operatorPublisher = makeOperator(passthrough)
        let emptySubscriber =
            TrackingSubscriberBase<Operator.Output, Operator.Failure>(onDeinit: onDeinit)
        XCTAssertTrue(emptySubscriber.history.isEmpty,
                      "Lifecycle test #1: the subscriber's history should be empty",
                      file: file,
                      line: line)
        operatorPublisher.subscribe(emptySubscriber)
        passthrough.send(valueToBeSent)
        passthrough.send(completion: .failure("failure"))
    }

    if cancellingSubscriptionReleasesSubscriber {
        XCTAssertEqual(deinitCounter,
                       1,
                       """
                       Lifecycle test #1: deinit should be called, because \
                       the subscription has completed
                       """,
                       file: file,
                       line: line)
    } else {
        XCTAssertEqual(deinitCounter,
                       0,
                       """
                       Lifecycle test #1: deinit should not be called
                       """,
                       file: file,
                       line: line)
    }

    // Lifecycle test #2
    do {
        let passthrough = PassthroughSubject<UpstreamOutput, TestingError>()
        let operatorPublisher = makeOperator(passthrough)
        let emptySubscriber =
            TrackingSubscriberBase<Operator.Output, Operator.Failure>(onDeinit: onDeinit)
        operatorPublisher.subscribe(emptySubscriber)
    }

    XCTAssertEqual(deinitCounter,
                   cancellingSubscriptionReleasesSubscriber ? 1 : 0,
                   """
                   Lifecycle test #2: deinit should not be called, \
                   because the subscription is never cancelled
                   """,
                   file: file,
                   line: line)

    // Lifecycle test #3

    var subscription: Subscription?

    do {
        let passthrough = PassthroughSubject<UpstreamOutput, TestingError>()
        let operatorPublisher = makeOperator(passthrough)
        let emptySubscriber = TrackingSubscriberBase<Operator.Output, Operator.Failure>(
            receiveSubscription: { subscription = $0; $0.request(.unlimited) },
            onDeinit: onDeinit
        )
        operatorPublisher.subscribe(emptySubscriber)
        passthrough.send(valueToBeSent)
    }

    XCTAssertEqual(deinitCounter,
                   cancellingSubscriptionReleasesSubscriber ? 1 : 0,
                   """
                   Lifecycle test #3: deinit should not be called, \
                   because the subscription is not cancelled yet
                   """,
                   file: file,
                   line: line)

    try XCTUnwrap(subscription,
                  "Lifecycle test #3: subscription should be saved",
                  file: file,
                  line: line)
        .cancel()

    if cancellingSubscriptionReleasesSubscriber {
        XCTAssertEqual(deinitCounter,
                       2,
                       """
                       Lifecycle test #3: deinit should be called, because
                       the subscription has been cancelled
                       """,
                       file: file,
                       line: line)
    } else {
        XCTAssertEqual(deinitCounter,
                       0,
                       "Lifecycle test #3: deinit should not be called",
                       file: file,
                       line: line)
    }

    // Lifecycle test #4

    var subscriberDestroyed = false

    do {
        let passthrough = PassthroughSubject<UpstreamOutput, TestingError>()
        let operatorPublisher = makeOperator(passthrough)
        let emptySubscriber = CleaningUpSubscriber<Operator.Output, Operator.Failure> {
            subscriberDestroyed = true
        }
        operatorPublisher.subscribe(emptySubscriber)
        passthrough.send(completion: .finished)
    }

    if finishingIsPassedThrough {
        XCTAssertTrue(subscriberDestroyed,
                      "Lifecycle test #4: deinit should be called",
                      file: file,
                      line: line)
    } else {
        XCTAssertFalse(subscriberDestroyed,
                       "Lifecycle test #4: deinit should not be called",
                       file: file,
                       line: line)
    }
}
