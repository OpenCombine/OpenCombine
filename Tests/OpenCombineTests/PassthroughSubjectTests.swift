//
//  PassthroughSubjectTests.swift
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
final class PassthroughSubjectTests: XCTestCase {

    private typealias Sut = PassthroughSubject<Int, TestingError>

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
            0, 0, 0, 0, 0, 1, 11, 2, 1, 20, 2, 12, 4, 5, 20, 10, 20, 12, 13, 20, 20,
            20, 20, 20, 20
        ]

        for initialDemand in initialDemands {
            for subsequentDemand in subsequentDemands {

                var subscriptions: [Subscription] = []
                var inputs: [Int] = []
                var completions: [Subscribers.Completion<TestingError>] = []

                var i = 0

                let passthrough = Sut()
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

                passthrough.subscribe(subscriber)

                XCTAssertEqual(subscriptions.count, 1)
                XCTAssertEqual(inputs.count, 0)
                XCTAssertEqual(completions.count, 0)

                for j in 0..<20 {
                    passthrough.send(j)
                }

                passthrough.send(completion: .finished)

                XCTAssertEqual(subscriptions.count, 1)
                XCTAssertEqual(completions.count, 1)

                numberOfInputsHistory.append(inputs.count)
            }
        }

        XCTAssertEqual(numberOfInputsHistory, expectedNumberOfInputsHistory)
    }

    func testCrashOnZeroInitialDemand() {
        assertCrashes {
            let subscriber = TrackingSubscriber(
                receiveSubscription: { $0.request(.none) }
            )

            Sut().subscribe(subscriber)
        }
    }

    func testSendFailureCompletion() {
        let passthrough = Sut()
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                subscription.request(.unlimited)
            }
        )

        passthrough.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("PassthroughSubject")])

        passthrough.send(completion: .failure(.oops))

        XCTAssertEqual(subscriber.history, [.subscription("PassthroughSubject"),
                                            .completion(.failure(.oops))])
    }

    func testMultipleSubscriptions() {

        let passthrough = Sut()

        final class MySubscriber: Subscriber {
            typealias Input = Sut.Output
            typealias Failure = Sut.Failure

            let sut: Sut

            var subscriptions: [Subscription] = []
            var inputs: [Int] = []
            var completions: [Subscribers.Completion<TestingError>] = []

            init(sut: Sut) {
                self.sut = sut
            }

            func receive(subscription: Subscription) {
                subscription.request(.unlimited)
                subscriptions.append(subscription)

                if subscriptions.count < 10 {
                    // This must recurse
                    sut.subscribe(self)
                }
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                inputs.append(input)
                return .none
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                completions.append(completion)
            }
        }

        let subscriber = MySubscriber(sut: passthrough)

        passthrough.subscribe(subscriber)

        XCTAssertEqual(subscriber.subscriptions.count, 10)
        XCTAssertEqual(subscriber.inputs.count, 0)
        XCTAssertEqual(subscriber.completions.count, 0)

        passthrough.subscribe(subscriber)

        XCTAssertEqual(subscriber.subscriptions.count, 11)
        XCTAssertEqual(subscriber.inputs.count, 0)
        XCTAssertEqual(subscriber.completions.count, 0)

        passthrough.send(0)

        XCTAssertEqual(subscriber.inputs, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])

        for (i, subscription) in subscriber.subscriptions.enumerated()
            where i.isMultiple(of: 2)
        {
            subscription.cancel()
        }
        passthrough.send(1)

        XCTAssertEqual(
            subscriber.inputs,
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1]
        )
    }

    // Reactive Streams Spec: Rule #6
    func testMultipleCompletions() {

        var subscriptions: [Subscription] = []
        var inputs: [Int] = []
        var completions: [Subscribers.Completion<TestingError>] = []

        let passthrough = Sut()
        let subscriber = AnySubscriber<Int, TestingError>(
            receiveSubscription: { subscription in
                subscriptions.append(subscription)
                subscription.request(.unlimited)
            },
            receiveValue: { value in
                inputs.append(value)
                return .none
            },
            receiveCompletion: { completion in
                passthrough.send(completion: .failure("must not recurse"))
                completions.append(completion)
            }
        )

        passthrough.subscribe(subscriber)
        passthrough.send(42)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(completions.count, 0)

        passthrough.send(completion: .finished)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(completions.count, 1)

        passthrough.send(completion: .finished)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(completions.count, 1)

        passthrough.send(completion: .failure("oops"))

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(completions.count, 1)
    }

    // Reactive Streams Spec: Rule #6
    func testValuesAfterCompletion() {
        var subscriptions: [Subscription] = []
        var inputs: [Int] = []
        var completions: [Subscribers.Completion<TestingError>] = []

        let passthrough = Sut()
        let subscriber = AnySubscriber<Int, TestingError>(
            receiveSubscription: { subscription in
                subscriptions.append(subscription)
                subscription.request(.unlimited)
            },
            receiveValue: { value in
                inputs.append(value)
                return .none
            },
            receiveCompletion: { completion in
                passthrough.send(42)
                completions.append(completion)
            }
        )

        passthrough.subscribe(subscriber)

        passthrough.send(42)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(completions.count, 0)

        passthrough.send(completion: .finished)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(completions.count, 1)

        passthrough.send(42)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 1)
        XCTAssertEqual(completions.count, 1)
    }

    func testSubscriptionAfterCompletion() {
        let passthrough = Sut()
        passthrough.send(completion: .finished)

        let subscriber = TrackingSubscriber()
        passthrough.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])
    }

    func testSendSubscription() {
        let subscription1 = CustomSubscription()
        let passthrough = Sut()

        passthrough.send(subscription: subscription1)
        XCTAssertEqual(subscription1.history, [])

        let subscriber1 = TrackingSubscriber(receiveSubscription: { $0.request(.max(1)) })
        passthrough.subscribe(subscriber1)

        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])
        XCTAssertEqual(subscriber1.history, [.subscription("PassthroughSubject")])

        let subscriber2 = TrackingSubscriber(receiveSubscription: { $0.request(.max(2)) })
        passthrough.subscribe(subscriber2)

        XCTAssertEqual(subscription1.history, [.requested(.unlimited)])
        XCTAssertEqual(subscriber1.history, [.subscription("PassthroughSubject")])
        XCTAssertEqual(subscriber2.history, [.subscription("PassthroughSubject")])

        passthrough.send(subscription: subscription1)
        XCTAssertEqual(subscription1.history, [.requested(.unlimited),
                                               .requested(.unlimited)])

        passthrough.send(0)
        passthrough.send(0)

        let subscription2 = CustomSubscription()
        passthrough.send(subscription: subscription2)
        XCTAssertEqual(subscription2.history, [.requested(.unlimited)])
    }

    func testCompletion() throws {
        let passthrough = Sut()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )

        passthrough.subscribe(tracking)

        try XCTUnwrap(downstreamSubscription).request(.max(12))

        passthrough.send(1)

        expectedChildren(
            ("parent", .contains("PassthroughSubject")),
            ("downstream", .contains("TrackingSubscriberBase")),
            ("demand", "max(11)"),
            ("subject", .contains("PassthroughSubject"))
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        passthrough.send(completion: .finished)

        expectedChildren(
            ("parent", "nil"),
            ("downstream", "nil"),
            ("demand", "max(11)"),
            ("subject", "nil")
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject"),
                                          .value(1),
                                          .completion(.finished)])

        passthrough.send(completion: .failure(.oops))
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).request(.max(3))

        expectedChildren(
            ("parent", "nil"),
            ("downstream", "nil"),
            ("demand", "max(11)"),
            ("subject", "nil")
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject"),
                                          .value(1),
                                          .completion(.finished)])
    }

    func testCancellation() throws {
        let passthrough = Sut()
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )

        passthrough.subscribe(tracking)

        try XCTUnwrap(downstreamSubscription).request(.max(12))

        passthrough.send(1)

        expectedChildren(
            ("parent", .contains("PassthroughSubject")),
            ("downstream", .contains("TrackingSubscriberBase")),
            ("demand", "max(11)"),
            ("subject", .contains("PassthroughSubject"))
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).request(.max(3))
        try XCTUnwrap(downstreamSubscription).request(.max(4))

        expectedChildren(
            ("parent", "nil"),
            ("downstream", "nil"),
            ("demand", "max(11)"),
            ("subject", "nil")
        )(Mirror(reflecting: try XCTUnwrap(downstreamSubscription)))

        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject"),
                                          .value(1)])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = { deinitCounter += 1 }

        do {
            let passthrough = Sut()
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            passthrough.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        XCTAssertEqual(deinitCounter, 1)

        do {
            let passthrough = Sut()
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            passthrough.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let passthrough = Sut()
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            passthrough.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 1)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 1)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 2)
    }

    func testCancelsUpstreamSubscriptionsOnDeinit() {
        let subscription = CustomSubscription()
        do {
            let passthrough = Sut()
            for _ in 0 ..< 5 {
                passthrough.send(subscription: subscription)
            }
            XCTAssertEqual(subscription.history, [])
        }

        XCTAssertEqual(subscription.history, [.cancelled,
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
                let subject = Sut()
                do {
                    let subscriber = TrackingSubscriber(receiveSubscription: {
                        weakSubscription = $0 as AnyObject
                    })
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
            description: "PassthroughSubject",
            customMirror: expectedChildren(
                ("parent", .contains("PassthroughSubject")),
                ("downstream", .contains("TrackingSubscriberBase")),
                ("demand", "max(0)"),
                ("subject", .contains("PassthroughSubject"))
            ),
            playgroundDescription:  "PassthroughSubject",
            sut: PassthroughSubject<Int, Error>()
        )
    }
}
