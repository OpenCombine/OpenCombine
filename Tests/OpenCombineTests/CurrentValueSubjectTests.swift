//
//  CurrentValueSubjectTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CurrentValueSubjectTests: XCTestCase {

    private typealias Sut = CurrentValueSubject<Int, TestingError>

    // Reactive Streams Spec: Rules #1, #2, #9
    func testRequestingDemand() {

        let initialDemands: [Subscribers.Demand?] = [
            nil,
            .max(1),
            .max(2),
            .max(10),
            .unlimited
        ]

        let subsequentDemands: [[Subscribers.Demand]] = [
            Array(repeating: .max(0), count: 5),
            Array(repeating: .max(1), count: 10),
            [.max(1), .max(0), .max(1), .max(0)],
            [.max(0), .max(1), .max(2)],
            [.unlimited, .max(1)]
        ]

        var numberOfInputsHistory: [Int] = []
        let expectedNumberOfInputsHistory = [
            0, 0, 0, 0, 0, 1, 11, 2, 1, 22, 2, 12, 4, 5, 22, 10, 20, 12, 13,
            22, 22, 22, 22, 22, 22
        ]

        for initialDemand in initialDemands {
            for subsequentDemand in subsequentDemands {

                var subscriptions: [Subscription] = []
                var inputs: [Int] = []
                var completions: [Subscribers.Completion<TestingError>] = []

                var i = 0

                let cvs = Sut(112)
                let subscriber = AnySubscriber<Int, TestingError>(
                    receiveSubscription: { subscription in
                        subscriptions.append(subscription)
                        initialDemand.map(subscription.request)
                    },
                    receiveValue: { value in
                        defer { i += 1 }
                        inputs.append(value)
                        return i < subsequentDemand.endIndex ? subsequentDemand[i] : .none
                    },
                    receiveCompletion: { completion in
                        completions.append(completion)
                    }
                )

                XCTAssertEqual(subscriptions.count, 0)
                XCTAssertEqual(inputs.count, 0)
                XCTAssertEqual(completions.count, 0)

                cvs.value -= 1

                XCTAssertEqual(inputs.count, 0)

                cvs.subscribe(subscriber)

                XCTAssertEqual(subscriptions.count, 1)
                XCTAssertEqual(inputs.count, initialDemand == nil ? 0 : 1)
                XCTAssertEqual(inputs.first, initialDemand == nil ? nil : 111)
                XCTAssertEqual(completions.count, 0)

                for _ in 0..<20 {
                    cvs.value += 1
                }

                let value = cvs.value
                cvs.value = value

                cvs.send(completion: .finished)

                XCTAssertEqual(subscriptions.count, 1)
                XCTAssertEqual(completions.count, 1)

                numberOfInputsHistory.append(inputs.count)
            }
        }

        XCTAssertEqual(numberOfInputsHistory, expectedNumberOfInputsHistory)
    }

    func testRequestSeveralTimes() throws {
        let cvs = Sut(-1)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        cvs.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("CurrentValueSubject")])

        try XCTUnwrap(downstreamSubscription).request(.max(2))
        try XCTUnwrap(downstreamSubscription).request(.max(3))
        try XCTUnwrap(downstreamSubscription).request(.max(1))

        XCTAssertEqual(tracking.history, [.subscription("CurrentValueSubject"),
                                          .value(-1)])

        for i in 0 ..< 10 {
            cvs.send(i)
        }

        XCTAssertEqual(tracking.history, [.subscription("CurrentValueSubject"),
                                          .value(-1),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4)])
    }

    func testCrashOnZeroInitialDemand() {
        assertCrashes {
            let subscriber = TrackingSubscriber(
                receiveSubscription: { $0.request(.none) }
            )

            Sut(1).subscribe(subscriber)
        }
    }

    func testSendFailureCompletion() {
        let cvs = Sut(0)
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                subscription.request(.unlimited)
            }
        )

        cvs.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(0)])

        cvs.value += 3

        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(0),
                                            .value(3)])

        cvs.send(completion: .failure(.oops))

        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(0),
                                            .value(3),
                                            .completion(.failure(.oops))])
    }

    func testChangeValueAfterCompletion() {
        let cvs = Sut(0)
        cvs.send(completion: .finished)
        cvs.value = 42
        XCTAssertEqual(cvs.value, 42)
    }

    func testSendValueAfterCompletion() {
        let cvs = Sut(0)
        cvs.send(completion: .finished)
        cvs.send(42)
        XCTAssertEqual(cvs.value, 0)
    }

    func testMultipleSubscriptions() {

        let cvs = Sut(112)

        final class MySubscriber: Subscriber {
            typealias Input = Sut.Output
            typealias Failure = Sut.Failure

            let sut: Sut
            let tracking = TrackingSubscriber()

            init(sut: Sut) {
                self.sut = sut
            }

            func receive(subscription: Subscription) {
                subscription.request(.unlimited)
                tracking.receive(subscription: subscription)

                if tracking.subscriptions.count < 10 {
                    // This must recurse
                    sut.subscribe(self)
                }
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return tracking.receive(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                tracking.receive(completion: completion)
            }
        }

        let subscriber = MySubscriber(sut: cvs)

        cvs.subscribe(subscriber)

        XCTAssertEqual(subscriber.tracking.history,
                       [.value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject")])

        cvs.subscribe(subscriber)

        XCTAssertEqual(subscriber.tracking.history,
                       [.value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject")])

        for (i, subscription) in subscriber.tracking.subscriptions.enumerated()
            where i.isMultiple(of: 2)
        {
            subscription.cancel()
        }
        cvs.value = 200

        XCTAssertEqual(subscriber.tracking.history,
                       [.value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(112),
                        .subscription("CurrentValueSubject"),
                        .value(200),
                        .value(200),
                        .value(200),
                        .value(200),
                        .value(200)])
    }

    // Reactive Streams Spec: Rule #6
    func testMultipleCompletions() {

        let cvs = Sut(112)
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                subscription.request(.unlimited)
            },
            receiveCompletion: { completion in
                cvs.send(completion: .failure("must not recurse"))
            }
        )

        cvs.subscribe(subscriber)
        cvs.value = 42
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(112),
                                            .value(42)])

        cvs.send(completion: .finished)
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(112),
                                            .value(42),
                                            .completion(.finished)])

        cvs.send(completion: .finished)
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(112),
                                            .value(42),
                                            .completion(.finished)])

        cvs.send(completion: .failure("oops"))
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(112),
                                            .value(42),
                                            .completion(.finished)])
    }

    // Reactive Streams Spec: Rule #6
    func testValuesAfterCompletion() {
        let cvs = Sut(112)
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                subscription.request(.unlimited)
            },
            receiveCompletion: { _ in
                cvs.value = 42
            }
        )

        cvs.subscribe(subscriber)

        cvs.value = 44
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(112),
                                            .value(44)])

        cvs.send(completion: .finished)
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(112),
                                            .value(44),
                                            .completion(.finished)])

        cvs.value = 1201
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(112),
                                            .value(44),
                                            .completion(.finished)])
    }

    func testSubscriptionAfterCompletion() {
        let passthrough = Sut(0)
        passthrough.send(completion: .finished)

        let subscriber = TrackingSubscriber()
        passthrough.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])
    }

    func testSubscriptionAfterSend() {
        // Given
        let passthrough = Sut(0)
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                subscription.request(.unlimited)
            })

        // When
        passthrough.send(2)
        passthrough.subscribe(subscriber)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(2)])
    }

    func testSubscriptionAfterSet() {
        // Given
        let passthrough = Sut(0)
        let subscriber = TrackingSubscriber(receiveSubscription: { subscription in
            subscription.request(.unlimited)
        })

        // When
        passthrough.value = 3
        passthrough.subscribe(subscriber)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                            .value(3)])
    }

    func testSendSubscription() {
        let subscription1 = CustomSubscription()
        let cvs = Sut(1)

        cvs.send(subscription: subscription1)
        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])

        let subscriber1 = TrackingSubscriber(receiveSubscription: { $0.request(.max(1)) })
        cvs.subscribe(subscriber1)

        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])
        XCTAssertEqual(subscriber1.history, [.subscription("CurrentValueSubject"),
                                             .value(1)])

        let subscriber2 = TrackingSubscriber(receiveSubscription: { $0.request(.max(2)) })
        cvs.subscribe(subscriber2)

        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])
        XCTAssertEqual(subscriber1.history, [.subscription("CurrentValueSubject"),
                                             .value(1)])
        XCTAssertEqual(subscriber2.history, [.subscription("CurrentValueSubject"),
                                             .value(1)])

        cvs.send(subscription: subscription1)
        XCTAssertEqual(subscription1.history, [.requested(.unlimited),
                                               .requested(.unlimited)])

        cvs.send(0)
        cvs.send(0)

        let subscription2 = CustomSubscription()
        cvs.send(subscription: subscription2)
        XCTAssertEqual(subscription2.history, [.requested(.unlimited)])
    }

    func testCompletion() throws {
        let passthrough = Sut(42)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )

        passthrough.subscribe(tracking)

        try XCTUnwrap(downstreamSubscription).request(.max(12))

        passthrough.send(1)

        expectedChildren(
            ("parent", .contains("CurrentValueSubject")),
            ("downstream", .contains("TrackingSubscriberBase")),
            ("demand", "max(10)"),
            ("subject", .contains("CurrentValueSubject"))
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        passthrough.send(completion: .finished)

        expectedChildren(
            ("parent", "nil"),
            ("downstream", "nil"),
            ("demand", "max(10)"),
            ("subject", "nil")
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        XCTAssertEqual(tracking.history, [.subscription("CurrentValueSubject"),
                                          .value(42),
                                          .value(1),
                                          .completion(.finished)])

        passthrough.send(completion: .failure(.oops))
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).request(.max(3))

        expectedChildren(
            ("parent", "nil"),
            ("downstream", "nil"),
            ("demand", "max(10)"),
            ("subject", "nil")
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        XCTAssertEqual(tracking.history, [.subscription("CurrentValueSubject"),
                                          .value(42),
                                          .value(1),
                                          .completion(.finished)])
    }

    func testCancellation() throws {
        let cvs = Sut(42)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )

        cvs.subscribe(tracking)

        try XCTUnwrap(downstreamSubscription).request(.max(12))

        cvs.send(1)

        expectedChildren(
            ("parent", .contains("CurrentValueSubject")),
            ("downstream", .contains("TrackingSubscriberBase")),
            ("demand", "max(10)"),
            ("subject", .contains("CurrentValueSubject"))
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).request(.max(3))
        try XCTUnwrap(downstreamSubscription).request(.max(4))

        expectedChildren(
            ("parent", "nil"),
            ("downstream", "nil"),
            ("demand", "max(10)"),
            ("subject", "nil")
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        XCTAssertEqual(tracking.history, [.subscription("CurrentValueSubject"),
                                          .value(42),
                                          .value(1)])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = {
            deinitCounter += 1
        }

        do {
            let cvs = Sut(0)
            let subscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(subscriber.history.isEmpty)

            cvs.subscribe(subscriber)
            XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject")])

            cvs.value += 1
            XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject")])

            cvs.send(completion: .failure(.oops))
            XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                                .completion(.failure(.oops))])
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let cvs = Sut(0)
            let subscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(subscriber.history.isEmpty)
            cvs.subscribe(subscriber)
            XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                                .value(0)])
            cvs.send(31)
            XCTAssertEqual(subscriber.history, [.subscription("CurrentValueSubject"),
                                                .value(0),
                                                .value(31)])
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 1)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 2)
    }

    func testCancelsUpstreamSubscriptionsOnDeinit() {
        let subscription = CustomSubscription()
        do {
            let cvs = Sut(42)
            for _ in 0 ..< 5 {
                cvs.send(subscription: subscription)
            }
            XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                                  .requested(.unlimited),
                                                  .requested(.unlimited),
                                                  .requested(.unlimited),
                                                  .requested(.unlimited)])
        }

        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .requested(.unlimited),
                                              .requested(.unlimited),
                                              .requested(.unlimited),
                                              .requested(.unlimited),
                                              .cancelled,
                                              .cancelled,
                                              .cancelled,
                                              .cancelled,
                                              .cancelled])
    }

    func testReleasesEverythingOnTermination() {

        enum TerminationReason: CaseIterable {
            case cancelled
            case finished
            case failed
        }

        for reason in TerminationReason.allCases {
            weak var weakSubscriber: TrackingSubscriber?
            weak var weakSubject: Sut?
            weak var weakSubscription: AnyObject?

            do {
                let subject = Sut(42)
                do {
                    let subscriber = TrackingSubscriber(
                        receiveSubscription: {
                            weakSubscription = $0 as AnyObject
                        }
                    )
                    weakSubscriber = subscriber
                    weakSubject = subject

                    subject.subscribe(subscriber)
                }

                switch reason {
                case .cancelled:
                    (weakSubscription as? Subscription)?.cancel()
                case .finished:
                    subject.send(completion: .finished)
                case .failed:
                    subject.send(completion: .failure(.oops))
                }

                XCTAssertNil(weakSubscriber, "Subscriber leaked - \(reason)")
                XCTAssertNil(weakSubscription, "Subscription leaked - \(reason)")
            }

            XCTAssertNil(weakSubject, "Subject leaked - \(reason)")
        }
    }

    func testConduitReflection() throws {
        try testSubscriptionReflection(
            description: "CurrentValueSubject",
            customMirror: expectedChildren(
                ("parent", .contains("CurrentValueSubject")),
                ("downstream", .contains("TrackingSubscriberBase")),
                ("demand", "max(0)"),
                ("subject", .contains("CurrentValueSubject"))
            ),
            playgroundDescription:  "CurrentValueSubject",
            sut: CurrentValueSubject<Int, Error>(42)
        )
    }
}
