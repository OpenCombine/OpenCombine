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
    ]

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

                let passthrough = PassthroughSubject<Int, TestingError>()
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
                    })

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
}
