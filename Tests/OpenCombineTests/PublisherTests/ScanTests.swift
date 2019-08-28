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
    static let allTests = [
        ("testEmpty", testEmpty),
        ("testError", testError),
        ("testTryScanFailureBecauseOfThrow", testTryScanFailureBecauseOfThrow),
        ("testTryScanFailureOnCompletion", testTryScanFailureOnCompletion),
        ("testTryScanSuccess", testTryScanSuccess),
        ("testRange", testRange),
        ("testNoDemand", testNoDemand),
        ("testDemandSubscribe", testDemandSubscribe),
        ("testDemandSend", testDemandSend),
        ("testCompletion", testCompletion),
        ("testScanCancel", testScanCancel),
        ("testTryScanCancel", testTryScanCancel),
        ("testCancelAlreadyCancelled", testCancelAlreadyCancelled),
        ("testLifecycle", testLifecycle),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    func testEmpty() {
        // Given
        let tracking = TrackingSubscriberBase<String, TestingError>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual(String(describing: $0), "Scan")
            }
        )
        // When
        publisher.scan("", String.init).subscribe(tracking)
        // Then
        XCTAssertEqual(tracking.history, [.subscription("PassthroughSubject")])
    }

    func testError() {
        // Given
        let expectedError = TestingError.oops
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        let publisher = CustomPublisher(subscription: CustomSubscription())
        // When
        publisher.scan(666, { $0 + $1 * 2 }).subscribe(tracking)
        publisher.send(completion: .failure(expectedError))
        publisher.send(completion: .failure(expectedError))
        // Then
        XCTAssertEqual(tracking.history, [
            .subscription("CustomSubscription"),
            .completion(.failure(expectedError)),
            .completion(.failure(expectedError))
        ])
    }

    func testTryScanFailureBecauseOfThrow() {
        var counter = 0 // How many times the transform is called?

        let publisher = PassthroughSubject<Int, Error>()
        let scan = publisher.tryScan(0) { (accum, value) -> Int in
            counter += 1
            if value == 100 {
                throw "too much" as TestingError
            }
            return value * 2
        }
        let tracking = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.send(1)
        scan.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(100)
        publisher.send(9)
        publisher.send(completion: .finished)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryScan"),
                        .value(4),
                        .value(6),
                        .completion(.failure("too much" as TestingError))])

        XCTAssertEqual(counter, 3)
    }

    func testTryScanFailureOnCompletion() {

        let publisher = PassthroughSubject<Int, Error>()
        let scan = publisher.tryScan(0) { $0 + $1 * 2 }

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        scan.subscribe(tracking)
        publisher.send(completion: .failure(TestingError.oops))
        publisher.send(2)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryScan"),
                        .completion(.failure(TestingError.oops))])
    }

    func testTryScanSuccess() {
        let publisher = PassthroughSubject<Int, Error>()
        let scan = publisher.tryScan(0) { $0 + $1 * 2 }

        let tracking = TrackingSubscriberBase<Int, Error>()

        publisher.send(1)
        scan.subscribe(tracking)
        publisher.send(completion: .finished)
        publisher.send(2)

        XCTAssertEqual(tracking.history,
                       [.subscription("TryScan"),
                        .completion(.finished)])
    }

    func testRange() {
        // Given
        let publisher = PassthroughSubject<Int, TestingError>()
        let scan = publisher.scan(0) { $0 + $1 * 2 }
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        // When
        publisher.send(1)
        scan.subscribe(tracking)
        publisher.send(2)
        publisher.send(3)
        publisher.send(completion: .finished)
        publisher.send(5)
        // Then
        XCTAssertEqual(tracking.history, [
            .subscription("PassthroughSubject"),
            .value(4),
            .value(10),
            .completion(.finished)
        ])
    }

    func testNoDemand() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let scan = publisher.scan(0) { $0 + $1 * 2 }
        let tracking = TrackingSubscriber()
        // When
        scan.subscribe(tracking)
        // Then
        XCTAssertTrue(subscription.history.isEmpty)
    }

    func testDemandSubscribe() {
        // Given
        let expectedSubscribeDemand = 42
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let scan = publisher.scan(0) { $0 + $1 * 2 }
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(expectedSubscribeDemand)) }
        )
        // When
        scan.subscribe(tracking)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.max(expectedSubscribeDemand))])
    }

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

    func testCompletion() {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let scan = publisher.scan(0) { $0 + $1 * 2 }
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        // When
        scan.subscribe(tracking)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited)])
        XCTAssertEqual(
            tracking.history,
            [.subscription("CustomSubscription"), .completion(.finished)]
        )
    }

    func testScanCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let scan = publisher.scan(0) { $0 + $1 * 2 }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        scan.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send(1), .none)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testTryScanCancel() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let scan = publisher.tryScan(0) { $0 + $1 * 2 }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Error>(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        scan.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        XCTAssertEqual(publisher.send(1), .none)
        publisher.send(completion: .finished)
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited), .cancelled])
    }

    func testCancelAlreadyCancelled() throws {
        // Given
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)
        let scan = publisher.scan(0) { $0 + $1 * 2 }
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
            downstreamSubscription = $0
        })
        // When
        scan.subscribe(tracking)
        try XCTUnwrap(downstreamSubscription).cancel()
        downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(downstreamSubscription).cancel()
        // Then
        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .cancelled,
                                              .requested(.unlimited),
                                              .cancelled])
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = { deinitCounter += 1 }

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let scan = passthrough.scan(0) { $0 + $1 * 2 }
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            scan.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 1)
        }

        XCTAssertEqual(deinitCounter, 1)

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let scan = passthrough.scan(0) { $0 + $1 * 2 }
            let emptySubscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            scan.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let scan = passthrough.scan(0) { $0 + $1 * 2 }
            let emptySubscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            scan.subscribe(emptySubscriber)
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

    // MARK: -
    func testTestSuiteIncludesAllTests() {
        // https://oleb.net/blog/2017/03/keeping-xctest-in-sync/
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let thisClass = type(of: self)
        let allTestsCount = thisClass.allTests.count
        let darwinCount = thisClass.defaultTestSuite.testCaseCount
        XCTAssertEqual(allTestsCount,
                       darwinCount,
                       "\(darwinCount - allTestsCount) tests are missing from allTests")
#endif
    }
}
