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

@available(macOS 10.15, *)
final class PassthroughSubjectTests: XCTestCase {

    static let allTests = [
        ("testRequestingDemand", testRequestingDemand),
        ("testMultipleSubscriptions", testMultipleSubscriptions),
        ("testMultipleCompletions", testMultipleCompletions),
        ("testValuesAfterCompletion", testValuesAfterCompletion),
        ("testLifecycle", testLifecycle),
        ("testSynchronization", testSynchronization),
        ("testShouldRemoveSubscriptionWhenCancel", testShouldRemoveSubscriptionWhenCancel)
    ]

    private typealias Sut = PassthroughSubject<Int, TestingError>

    // Reactive Streams Spec: Rules #1, #2, #9
    func testRequestingDemand() {

        let initialDemands: [Subscribers.Demand] = [
            .max(0),
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
                        subscription.request(initialDemand)
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

    func testLifecycle() {

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

        XCTAssertEqual(deinitCounter, 1) // We have a leak

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
        subscription?.cancel()
        XCTAssertEqual(deinitCounter, 2)
    }

    func testSynchronization() {

        let subscriptions = Atomic<[Subscription]>([])
        let inputs =  Atomic<[Int]>([])
        let completions = Atomic<[Subscribers.Completion<TestingError>]>([])

        let passthrough = Sut()
        let subscriber = AnySubscriber<Int, TestingError>(
            receiveSubscription: { subscription in
                subscriptions.do { $0.append(subscription) }
                subscription.request(.unlimited)
            },
            receiveValue: { value in
                inputs.do { $0.append(value) }
                return .none
            },
            receiveCompletion: { completion in
                completions.do { $0.append(completion) }
            }
        )

        race(
            {
                passthrough.subscribe(subscriber)
            },
            {
                passthrough.subscribe(subscriber)
            }
        )

        XCTAssertEqual(subscriptions.count, 200)

        race(
            {
                passthrough.send(31)
            },
            {
                passthrough.send(42)
            }
        )

        XCTAssertEqual(inputs.count, 40000)

        race(
            {
                subscriptions[0].request(.max(4))
            },
            {
                subscriptions[0].request(.max(10))
            }
        )

        race(
            {
                passthrough.send(completion: .finished)
            },
            {
                passthrough.send(completion: .failure(""))
            }
        )

        XCTAssertEqual(completions.count, 200)
    }
    
    func testShouldRemoveSubscriptionWhenCancel() {
        
        weak var subscription: AnyObject?
        
        let pub = PassthroughSubject<Int, Never>()
        
        let sub = AnySubscriber<Int, Never>(receiveSubscription: { (s) in
            subscription = s as AnyObject
            s.request(.max(1))
        }, receiveValue: { _ in
            return .none
        }, receiveCompletion: { _ in
        })
        
        pub.subscribe(sub)

        XCTAssertNotNil(subscription)
        
        pub.send(completion: .finished)
        
        XCTAssertNil(subscription)
    }
}
