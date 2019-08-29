//
//  ReplaceErrorTests.swift
//  OpenCombineTests
//
//  Created by Bogdan Vlad on 8/29/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ReplaceErrorTests: XCTestCase {
    static let allTests = [
        ("testEmpty", testEmpty),
        ("testError", testError),
        ("testSendingValueAndThenError", testSendingValueAndThenError),
        ("testLifecycle", testLifecycle),
        ("testCancelAlreadyCancelled", testCancelAlreadyCancelled),
        ("testFailingBeforeDemanding", testFailingBeforeDemanding),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]
    
    func testEmpty() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                        initialDemand: nil,
                        receiveValueDemand: .none,
                        createSut: { $0.replaceError(with: 42) })

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError")])
    }

    func testError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                initialDemand: .max(1),
                                receiveValueDemand: .none,
                                createSut: { $0.replaceError(with: 42) })

        helper.publisher.send(completion: .failure(TestingError.oops))
        
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"), .value(42), .completion(.finished)])
    }

    func testSendingValueAndThenError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                initialDemand: .max(1),
                                receiveValueDemand: .max(1),
                                createSut: { $0.replaceError(with: 42) })

        XCTAssertEqual(helper.publisher.send(41), .max(1))
        helper.publisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"), .value(41), .value(42), .completion(.finished)])
    }

    func testFailingBeforeDemanding() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                initialDemand: nil,
                                receiveValueDemand: .max(1),
                                createSut: { $0.replaceError(with: 42) })

        helper.publisher.send(completion: .failure(TestingError.oops))
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError")])

        helper.downstreamSubscription?.request(.unlimited)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceError"), .value(42), .completion(.finished)])
    }

    func testLifecycle() throws {
        var deinitCounter = 0

        let onDeinit = { deinitCounter += 1 }

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let replaceError = passthrough.replaceError(with: 10)
            let emptySubscriber = TrackingSubscriberBase<Int, Never>(
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            replaceError.print("test").subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            passthrough.send(completion: .failure("failure"))
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 0)

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let replaceError = passthrough.replaceError(with: 10)
            let emptySubscriber = TrackingSubscriberBase<Int, Never>(
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            replaceError.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            XCTAssertEqual(emptySubscriber.inputs.count, 0)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
        }

        XCTAssertEqual(deinitCounter, 0)

        var subscription: Subscription?

        do {
            let passthrough = PassthroughSubject<Int, TestingError>()
            let replaceError = passthrough.replaceError(with: 10)
            let emptySubscriber = TrackingSubscriberBase<Int, Never>(
                receiveSubscription: { subscription = $0; $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            XCTAssertTrue(emptySubscriber.history.isEmpty)
            replaceError.subscribe(emptySubscriber)
            XCTAssertEqual(emptySubscriber.subscriptions.count, 1)
            passthrough.send(31)
            XCTAssertEqual(emptySubscriber.inputs.count, 1)
            XCTAssertEqual(emptySubscriber.completions.count, 0)
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 0)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 0)
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                initialDemand: .unlimited,
                                receiveValueDemand: .max(1),
                                createSut: { $0.replaceError(with: 42) })
        
        helper.downstreamSubscription?.cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        helper.downstreamSubscription?.request(.unlimited)
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                              .cancelled])
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

private struct OtherError: Error {
    let original: Error

    init(_ original: Error) {
        self.original = original
    }
}
