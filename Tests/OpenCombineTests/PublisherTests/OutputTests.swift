//
//  OutputTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.11.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class OutputTests: XCTestCase {

    func testPrefixOperatorCorrectlyTranslatesToCountableRange() {
        let publisher = Empty<Void, Never>()
        XCTAssertEqual(publisher.prefix(89).range, 0 ..< 89)
        XCTAssertEqual(publisher.prefix(.max).range, 0 ..< .max)
        XCTAssertEqual(publisher.prefix(0).range, 0 ..< 0)
    }

    func testPrefixOperatorCrashesOnNegativeValues() {
        assertCrashes {
            _ = Empty<Void, Never>().prefix(-1)
        }
    }

    func testOutputAtOperatorCorrectlyTranslatesToCountableRange() {
        let publisher = Empty<Void, Never>()
        XCTAssertEqual(publisher.output(at: 89).range, 89 ..< 90)
    }

    func testOutputAtOperatorCrashesOnIntMax() {
        assertCrashes {
            _ = Empty<Void, Never>().output(at: .max)
        }
    }

    func testOutputAtOperatorCrashesOnNegativeValues() {
        assertCrashes {
            _ = Empty<Void, Never>().output(at: -1)
        }
    }

    func testOutputInOperatorCorrectlyTranslatesToCountableRange() {
        let publisher = Empty<Void, Never>()
        XCTAssertEqual(publisher.output(in: ..<8).range, 0 ..< 8)
        XCTAssertEqual(publisher.output(in: ...8).range, 0 ..< 9)
        XCTAssertEqual(publisher.output(in: 8...).range, 8 ..< .max)
        XCTAssertEqual(publisher.output(in: .max...).range, .max ..< .max)
        XCTAssertEqual(publisher.output(in: 4 ..< 5).range, 4 ..< 5)
        XCTAssertEqual(publisher.output(in: 4 ... 5).range, 4 ..< 6)

        let trackingRange = TrackingRangeExpression(12 ..< 14)
        _ = publisher.output(in: trackingRange)
        XCTAssertEqual(trackingRange.history, [.relativeTo(0 ..< .max)])
    }

    func testOutputInOperatorCrashesOnNegativeLowerBound() {
        assertCrashes {
            _ = Empty<Void, Never>().output(in: (-1)...)
        }
    }

    func testOutputInOperatorCrashesOnNegativeUpperBound() {
        assertCrashes {
            _ = Empty<Void, Never>()
                .output(in: Range(uncheckedBounds: (lower: 1, upper: -1)))
        }
    }

    func testDirectInitializationCrashesOnNegativeLowerBound() {
        assertCrashes {
            _ = Publishers.Output(upstream: Empty<Void, Never>(), range: -1 ..< 4)
        }
    }

    func testDirectInitializationCrashesOnNegativeUpperBound() {
        assertCrashes {
            _ = Publishers.Output(upstream: Empty<Void, Never>(),
                                  range: Range(uncheckedBounds: (lower: 1, upper: -1)))
        }
    }

    func testBasicBehavior() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(42),
                                        createSut: { $0.output(in: 3 ..< 7) })

        helper.tracking.onFinish = {
            XCTAssertEqual(helper.subscription.history, [.requested(.max(31)),
                                                         .requested(.max(32)),
                                                         .cancelled])
        }

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(1))
        XCTAssertEqual(helper.publisher.send(3), .max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription("Output")])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(31))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(32))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(31)),
                                                     .requested(.max(32))])

        XCTAssertEqual(helper.publisher.send(4), .max(42))
        XCTAssertEqual(helper.publisher.send(5), .max(42))
        XCTAssertEqual(helper.publisher.send(6), .max(42))
        XCTAssertEqual(helper.publisher.send(7), .max(42))
        XCTAssertEqual(helper.publisher.send(8), .none)
        XCTAssertEqual(helper.publisher.send(9), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Output"),
                                                 .value(4),
                                                 .value(5),
                                                 .value(6),
                                                 .value(7),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [.requested(.max(31)),
                                                     .requested(.max(32)),
                                                     .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(33))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.max(31)),
                                                     .requested(.max(32)),
                                                     .cancelled])
    }

    func testSendValuesAfterCompletion() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(2),
                                        createSut: { $0.output(in: 1 ..< 3) })

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(2))
        XCTAssertEqual(helper.publisher.send(3), .max(2))
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(5), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Output"),
                                                 .completion(.failure(.oops)),
                                                 .value(2),
                                                 .value(3)])
        XCTAssertEqual(helper.subscription.history, [])
    }

    func testSendValuesBeforeSubscription() throws {
        let publisher = CustomPublisher(subscription: nil)
        let output = publisher.output(in: 1 ..< 3)
        let tracking = TrackingSubscriber(receiveValue: { _ in .max(42) })
        output.subscribe(tracking)

        XCTAssertEqual(tracking.history, [])
        publisher.send(completion: .failure(.oops))
        XCTAssertEqual(publisher.send(1), .max(1))
        XCTAssertEqual(publisher.send(2), .max(42))
        XCTAssertEqual(publisher.send(3), .max(42))
        XCTAssertEqual(publisher.send(4), .none)
        XCTAssertEqual(publisher.send(5), .none)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.value(2), .value(3)])

        let subscription = CustomSubscription()
        publisher.send(subscription: subscription)

        XCTAssertEqual(tracking.history, [.value(2), .value(3), .subscription("Output")])

        XCTAssertEqual(publisher.send(6), .none)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history, [.value(2),
                                          .value(3),
                                          .subscription("Output"),
                                          .completion(.finished)])
    }

    func testOutputReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.output(in: ..<10) }
        )
    }

    func testOutputRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.output(in: 0 ..< 3) })
    }

    func testOutputCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.output(in: 0 ..< 3) })
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.output(in: 1 ..< 3) })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.publisher.send(1), .max(1))
        XCTAssertEqual(helper.publisher.send(2), .max(3))

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("Output"), .value(2)])
    }

    func testOutputReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.output(in: 1 ..< 3) }
    }

    func testOutputLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.output(in: 10 ..< 42) })
    }

    func testOutputReflection() throws {
        try testReflection(parentInput: String.self,
                           parentFailure: Never.self,
                           description: "Output",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "Output",
                           { $0.output(in: 10 ..< 42) })
    }
}
