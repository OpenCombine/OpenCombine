//
//  CountTests.swift
//
//
//  Created by Joseph Spadafora on 6/25/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class CountTests: XCTestCase {

    func testBasicBehavior() throws {
        try ReduceTests.testBasicReductionBehavior(expectedSubscription: "Count",
                                                   expectedResult: 5,
                                                   { $0.count() })
    }

    func testUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Count",
                                                  { $0.count() })
    }

    func testUpstreamFinishesImmediatelyWithDemand() {
        ReduceTests.testUpstreamFinishesImmediatelyWithDemand(
            expectedSubscription: "Count",
            expectedResult: 0,
            { $0.count() }
        )
    }

    func testUpstreamFinishesImmediatelyWithoutDemand() {
        ReduceTests.testUpstreamFinishesImmediatelyWithoutDemand(
            expectedSubscription: "Count",
            { $0.count() }
        )
    }

    func testCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.count() }
    }

    func testRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.count() }
    }

    func testReceiveSubscriptionTwice() throws {
        try ReduceTests
            .testReceiveSubscriptionTwice(expectedSubscription: "Count",
                                          expectedResult: .normalCompletion(1),
                                          { $0.count() })
    }

    func testCountReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.count() })
    }

    func testCountReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.count() }
        )
    }

    func testCountRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.count() })
    }

    func testCountCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.count() })
    }

    func testCountLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: false,
                          { $0.count() })
    }

    func testCountReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Count",
                           customMirror: reduceLikeOperatorMirror(),
                           playgroundDescription: "Count",
                           { $0.count() })
    }
}
