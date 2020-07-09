//
//  ScanTests.swift
//
//
//  Created by Eric Patey on 27.08.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ScanTests: XCTestCase {

    func testDemandSend() {
        var expectedReceiveValueDemand = 4
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let scan = publisher.scan(0) { $0 + $1 * 2 }
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in .max(expectedReceiveValueDemand) }
        )

        scan.subscribe(tracking)

        XCTAssertEqual(publisher.send(0), .max(4))

        expectedReceiveValueDemand = 120

        XCTAssertEqual(publisher.send(0), .max(120))
    }

    // MARK: - Scan

    func testScanEmpty() {
        let tracking = TrackingSubscriberBase<String, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "Scan")
            }
        )

        publisher.scan("", String.init(repeating:count:)).subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject")])
    }

    func testScanError() {
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        let publisher = CustomPublisher(subscription: CustomSubscription())

        publisher.scan(666, shouldNotBeCalled()).subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        publisher.send(completion: .failure(expectedError))

        XCTAssertEqual(tracking.history, [
            .subscription("CustomSubscription"),
            .completion(.failure(expectedError)),
            .completion(.failure(expectedError))
        ])
    }

    func testScanRange() {
        let publisher = CustomPublisher(subscription: CustomSubscription())
        let scan = publisher.scan(0) { $0 + $1 * 2 }
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })

        XCTAssertEqual(publisher.send(1), .none)
        scan.subscribe(tracking)
        XCTAssertEqual(publisher.send(2), .none)
        XCTAssertEqual(publisher.send(3), .none)
        XCTAssertEqual(publisher.send(4), .none)
        XCTAssertEqual(publisher.send(5), .none)
        publisher.send(completion: .finished)
        XCTAssertEqual(publisher.send(6), .none)

        XCTAssertEqual(tracking.history, [
            .subscription("CustomSubscription"),
            .value(4),
            .value(10),
            .value(18),
            .value(28),
            .completion(.finished),
            .value(40)
        ])
    }

    func testScanImmediateCompletion() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(3),
                                        receiveValueDemand: .none,
                                        createSut: { $0.scan(0, shouldNotBeCalled()) })
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(3))])
        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .completion(.finished)])
    }

    func testScanCancel() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.scan(0) { $0 + $1 * 2 } })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send(1), .none)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(2),
                                                 .completion(.finished),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .completion(.failure(.oops))])
    }

    func testScanCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.scan(0, shouldNotBeCalled()) })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(42))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled,
                                                     .requested(.max(42)),
                                                     .cancelled])
    }

    func testScanReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Scan",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriber")),
                               ("result", "0")
                           ),
                           playgroundDescription: "Scan",
                           subscriberIsAlsoSubscription: false,
                           { $0.scan(0, +) })
    }

    func testScanReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(0)],
                                                              demand: .max(42)),
                                           { $0.scan(0, +) })
    }

    func testScanCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.scan(0, shouldNotBeCalled()) }
        )
    }

    func testScanLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: true,
                          { $0.scan(0, +) })
    }

    // MARK: - TryScan

    func testTryScanFailureOnCompletion() {

        let publisher = CustomPublisher(subscription: CustomSubscription())
        let scan = publisher.tryScan(0) { $0 + $1 * 2 }

        let tracking = TrackingSubscriberBase<Int, Error>()

        XCTAssertEqual(publisher.send(1), .none)
        scan.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(publisher.send(2), .none)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryScan"),
                        .completion(.failure(TestingError.oops)),
                        .value(4)])
    }

    func testTryScanSuccess() {
        let publisher = CustomPublisher(subscription: CustomSubscription())
        let scan = publisher.tryScan(0) { $0 + $1 * 2 }

        let tracking = TrackingSubscriberBase<Int, Error>()

        XCTAssertEqual(publisher.send(1), .none)
        scan.subscribe(tracking)
        publisher.send(completion: .finished)
        XCTAssertEqual(publisher.send(2), .none)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryScan"),
                        .completion(.finished),
                        .value(4)])
    }

    func testTryScanReceiveSubscriptionTwice() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.tryScan(0, shouldNotBeCalled()) })

        XCTAssertEqual(helper.subscription.history, [])

        let secondSubscription = CustomSubscription()
        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.cancelled])
    }

    func testTryScanFailureBecauseOfThrow() {
        var counter = 0 // How many times the transform is called?

        func reducer(_ acc: Int, _ newValue: Int) throws -> Int {
            counter += 1
            if newValue == 100 {
                throw "too much" as TestingError
            }
            return newValue * 2
        }

        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .max(3),
                                        createSut: { $0.tryScan(0, reducer) })
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(2), .max(3))
        XCTAssertEqual(helper.publisher.send(3), .max(3))
        XCTAssertEqual(helper.publisher.send(100), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(helper.publisher.send(9), .max(3))
        XCTAssertEqual(helper.publisher.send(100), .none)

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription("TryScan"),
                        .value(4),
                        .value(6),
                        .completion(.failure("too much" as TestingError)),
                        .value(18)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])

        XCTAssertEqual(counter, 5)
    }

    func testTryScanCancel() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.tryScan(0) { $0 + $1 * 2 } })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        XCTAssertEqual(helper.publisher.send(1), .none)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited), .cancelled])
        XCTAssertEqual(helper.tracking.history, [.subscription("TryScan"),
                                                 .value(2)])
    }

    func testTryScanCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none,
                                        createSut: { $0.tryScan(0, shouldNotBeCalled()) })

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(42))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])
    }

    func testTryScanReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "TryScan",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriber")),
                               ("status", .anything),
                               ("result", "0")
                           ),
                           playgroundDescription: "TryScan",
                           { $0.tryScan(0, +) })
    }

    func testTryScanReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(0)],
                                                              demand: .max(42)),
                                           { $0.tryScan(0, +) })
    }

    func testTryScanRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.tryScan(0, shouldNotBeCalled()) })
    }

    func testTryScanCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.tryScan(0, shouldNotBeCalled()) })
    }

    func testTryScanCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.tryScan(0, shouldNotBeCalled()) }
        )
    }

    func testTryScanLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.tryScan(0, +) })
    }
}
