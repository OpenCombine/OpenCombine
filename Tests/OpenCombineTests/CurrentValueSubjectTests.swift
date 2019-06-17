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

@available(macOS 10.15, *)
final class CurrentValueSubjectTests: XCTestCase {

    static let allTests = [
        ("testRequestingDemand", testRequestingDemand),
        ("testMultipleSubscriptions", testMultipleSubscriptions),
        ("testMultipleCompletions", testMultipleCompletions),
        ("testValuesAfterCompletion", testValuesAfterCompletion),
        // TODO:
        // ("testLifecycle", testLifecycle),
        ("testSynchronization", testSynchronization),
    ]

    private typealias Sut = CurrentValueSubject<Int, TestingError>

    // Reactive Streams Spec: Rules #1, #2, #9
    func testRequestingDemand() {

        let initialDemands: [Subscribers.Demand?] = [
            nil,
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
            0, 0, 0, 0, 0, 1, 1, 1, 1, 22, 1, 11, 2, 1, 22, 2, 12, 4, 5, 22, 10, 20, 12,
            13, 22, 22, 22, 22, 22, 22
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

    func testMultipleSubscriptions() {

        let cvs = Sut(112)

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

        let subscriber = MySubscriber(sut: cvs)

        cvs.subscribe(subscriber)

        XCTAssertEqual(subscriber.subscriptions.count, 10)
        XCTAssertEqual(subscriber.inputs.count, 10)
        XCTAssertEqual(subscriber.completions.count, 0)

        cvs.subscribe(subscriber)

        XCTAssertEqual(subscriber.subscriptions.count, 11)
        XCTAssertEqual(subscriber.inputs.count, 11)
        XCTAssertEqual(subscriber.completions.count, 0)
    }

    // Reactive Streams Spec: Rule #6
    func testMultipleCompletions() {

        var subscriptions: [Subscription] = []
        var inputs: [Int] = []
        var completions: [Subscribers.Completion<TestingError>] = []

        let cvs = Sut(112)
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
                cvs.send(completion: .failure("must not recurse"))
                completions.append(completion)
            }
        )

        cvs.subscribe(subscriber)
        cvs.value = 42

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(completions.count, 0)

        cvs.send(completion: .finished)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(completions.count, 1)

        cvs.send(completion: .finished)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(completions.count, 1)

        cvs.send(completion: .failure("oops"))

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(completions.count, 1)
    }

    // Reactive Streams Spec: Rule #6
    func testValuesAfterCompletion() {
        var subscriptions: [Subscription] = []
        var inputs: [Int] = []
        var completions: [Subscribers.Completion<TestingError>] = []

        let cvs = Sut(112)
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
                cvs.value = 42
                completions.append(completion)
            }
        )

        cvs.subscribe(subscriber)

        cvs.value = 44

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(completions.count, 0)

        cvs.send(completion: .finished)

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(completions.count, 1)

        cvs.value = 1201

        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(completions.count, 1)
    }
    /* TODO: Figure out why Apple's Combine behaves this way, see FB6146252
    func testLifecycle() {

        var deinitCounter = 0

        let onDeinit = {
            deinitCounter += 1
        }

        do {
            let cvs = Sut(0)
            let subscriber = TrackingSubscriber(
                receiveSubscription: { $0.request(.none) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(subscriber.history.isEmpty)
            cvs.subscribe(subscriber)
            XCTAssertEqual(subscriber.countSubscriptions, 1)
            XCTAssertEqual(subscriber.countInputs, 1)
            cvs.value += 1
            XCTAssertEqual(subscriber.countInputs, 1)
            cvs.send(completion: .failure("failure"))
            XCTAssertEqual(subscriber.countCompletions, 1)
        }

        XCTAssertEqual(deinitCounter, 0)

        do {
            let cvs = Sut(0)
            let subscriber = TrackingSubscriber(
                receiveSubscription: { $0.request(.none) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(subscriber.history.isEmpty)
            cvs.subscribe(subscriber)
            XCTAssertEqual(subscriber.countSubscriptions, 1)
            XCTAssertEqual(subscriber.countInputs, 1)
            XCTAssertEqual(subscriber.countCompletions, 0)
        }

        XCTAssertEqual(deinitCounter, 0) // We have a leak

        var subscription: Subscription?

        do {
            let cvs = Sut(0)
            let subscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(subscriber.history.isEmpty)
            cvs.subscribe(subscriber)
            XCTAssertEqual(subscriber.countSubscriptions, 1)
            cvs.send(31)
            XCTAssertEqual(subscriber.countInputs, 2)
            XCTAssertEqual(subscriber.countCompletions, 0)
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 0)
        dump(subscription!)
        subscription?.cancel()
        XCTAssertEqual(deinitCounter, 1)
        dump(subscription!)
    }
    */


    func testSynchronization() {

        let subscriptions = Atomic<[Subscription]>([])
        let inputs =  Atomic<[Int]>([])
        let completions = Atomic<[Subscribers.Completion<TestingError>]>([])

        let cvs = Sut(112)
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
                cvs.subscribe(subscriber)
            },
            {
                cvs.subscribe(subscriber)
            }
        )

        XCTAssertEqual(subscriptions.value.count, 200)

        race(
            {
                cvs.value += 1
            },
            {
                cvs.value -= 1
            }
        )

        XCTAssertEqual(inputs.value.count, 40200)
        XCTAssertEqual(cvs.value, 112)

        race(
            {
                subscriptions.value[0].request(.max(4))
            },
            {
                subscriptions.value[0].request(.max(10))
            }
        )

        race(
            {
                cvs.send(completion: .finished)
            },
            {
                cvs.send(completion: .failure(""))
            }
        )

        XCTAssertEqual(completions.value.count, 200)
    }
}
