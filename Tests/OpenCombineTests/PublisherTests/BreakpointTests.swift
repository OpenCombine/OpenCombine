//
//  BreakpointTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class BreakpointTests: XCTestCase {

    func testReceiveSubscription() {
        var shouldStop = false
        var counter = 0
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1)) {
            $0.breakpoint(receiveSubscription: { _ in counter += 1; return shouldStop })
        }

        XCTAssertNotNil(helper.sut.receiveSubscription)
        XCTAssertNil(helper.sut.receiveOutput)
        XCTAssertNil(helper.sut.receiveCompletion)

        XCTAssertEqual(helper.publisher.send(12), .max(1))
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(21), .max(1))
        helper.publisher.send(subscription: CustomSubscription())

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(12),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .value(21),
                                                 .subscription("CustomSubscription")])
        XCTAssertEqual(helper.subscription.history, [])
        shouldStop = true
        XCTAssertEqual(counter, 2)
        assertCrashes {
            helper.publisher.send(subscription: CustomSubscription())
        }
    }

    func testReceiveValue() {
        var counter = 0
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1)) {
            $0.breakpoint(receiveOutput: { counter += 1; return $0 < 0 })
        }

        XCTAssertNil(helper.sut.receiveSubscription)
        XCTAssertNotNil(helper.sut.receiveOutput)
        XCTAssertNil(helper.sut.receiveCompletion)

        XCTAssertEqual(helper.publisher.send(12), .max(1))
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(21), .max(1))
        helper.publisher.send(subscription: CustomSubscription())

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(12),
                                                 .completion(.finished),
                                                 .completion(.failure(.oops)),
                                                 .value(21),
                                                 .subscription("CustomSubscription")])
        XCTAssertEqual(helper.subscription.history, [])
        XCTAssertEqual(counter, 2)
        assertCrashes {
            _ = helper.publisher.send(-1)
        }
    }

    func testReceiveCompletion() {
        var counter = 0
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1)) {
            $0.breakpoint(receiveCompletion: { counter += 1; return $0 == .finished })
        }

        XCTAssertNil(helper.sut.receiveSubscription)
        XCTAssertNil(helper.sut.receiveOutput)
        XCTAssertNotNil(helper.sut.receiveCompletion)

        XCTAssertEqual(helper.publisher.send(12), .max(1))
        helper.publisher.send(completion: .failure(.oops))
        helper.publisher.send(completion: .failure(.oops))
        XCTAssertEqual(helper.publisher.send(21), .max(1))
        helper.publisher.send(subscription: CustomSubscription())

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(12),
                                                 .completion(.failure(.oops)),
                                                 .completion(.failure(.oops)),
                                                 .value(21),
                                                 .subscription("CustomSubscription")])
        XCTAssertEqual(counter, 2)
        assertCrashes {
            helper.publisher.send(completion: .finished)
        }
    }

    func testBreakpointOnError() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1)) {
            $0.breakpointOnError()
        }

        XCTAssertNil(helper.sut.receiveSubscription)
        XCTAssertNil(helper.sut.receiveOutput)
        XCTAssertNotNil(helper.sut.receiveCompletion)

        XCTAssertEqual(helper.publisher.send(12), .max(1))
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)
        XCTAssertEqual(helper.publisher.send(21), .max(1))
        helper.publisher.send(subscription: CustomSubscription())

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(12),
                                                 .completion(.finished),
                                                 .completion(.finished),
                                                 .value(21),
                                                 .subscription("CustomSubscription")])

        XCTAssertEqual(helper.sut.receiveCompletion?(.finished), false)
        XCTAssertEqual(helper.sut.receiveCompletion?(.failure(.oops)), true)

        assertCrashes {
            helper.publisher.send(completion: .failure(.oops))
        }
    }

    func testCancelAlreadyCancelled() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .unlimited,
                                        receiveValueDemand: .none) {
            $0.breakpointOnError()
        }
        try XCTUnwrap(helper.downstreamSubscription).request(.max(14))
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).request(.max(100))
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .requested(.max(14)),
                                                     .cancelled,
                                                     .requested(.max(100)),
                                                     .cancelled])
    }

    func testBreakpointReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Breakpoint",
                           customMirror: childrenIsEmpty,
                           playgroundDescription: "Breakpoint",
                           subscriberIsAlsoSubscription: false,
                           { $0.breakpointOnError() })
    }
}
