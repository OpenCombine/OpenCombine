//
//  CollectTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 15.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CollectTests: XCTestCase {

    func testBasicBehavior() throws {
        try ReduceTests.testBasicReductionBehavior(expectedSubscription: "Collect",
                                                   expectedResult: [1, 2, 3, 4, 5],
                                                   { $0.collect() })
    }

    func testUpstreamFinishesWithError() {
        ReduceTests.testUpstreamFinishesWithError(expectedSubscription: "Collect",
                                                  { $0.collect() })
    }

    func testtestUpstreamFinishesImmediately() {
        ReduceTests.testUpstreamFinishesImmediately(expectedSubscription: "Collect",
                                                    expectedResult: [Int](),
                                                    { $0.collect() })
    }

    func testCancelAlreadyCancelled() throws {
        try ReduceTests.testCancelAlreadyCancelled { $0.collect() }
    }

    func testRequestsUnlimitedThenSendsSubscription() {
        ReduceTests.testRequestsUnlimitedThenSendsSubscription { $0.collect() }
    }

    func testReceiveSubscriptionTwice() throws {
        try ReduceTests
            .testReceiveSubscriptionTwice(expectedSubscription: "Collect",
                                          expectedResult: .normalCompletion([0]),
                                          { $0.collect() })
    }

    func testCollectReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([], demand: .none),
                                           { $0.collect() })
    }

    func testCollectReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.collect() }
        )
    }

    func testCollectRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.collect() })
    }

    func testCollectCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([.requested(.unlimited)]),
                                     { $0.collect() })
    }

    func testCollectLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.collect() })
    }

    func testCollectReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Collect",
                           customMirror: expectedChildren(("count", "0")),
                           playgroundDescription: "Collect",
                           { $0.collect() })
    }
}
