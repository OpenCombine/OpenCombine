//
//  AssertNoFailureTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class AssertNoFailureTests: XCTestCase {

    func testPassThroughInput() throws {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(2),
                                        createSut: { $0.assertNoFailure() })

        XCTAssertEqual(helper.publisher.send(1), .max(2))
        XCTAssertEqual(helper.publisher.send(2), .max(2))
        XCTAssertEqual(helper.publisher.send(3), .max(2))
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)

        let subscription2 = CustomSubscription()
        helper.publisher.send(subscription: subscription2)
        helper.publisher.send(subscription: subscription2)

        try XCTUnwrap(helper.downstreamSubscription).request(.max(42))
        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.tracking.history, [.subscription("CustomSubscription"),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .completion(.finished),
                                                 .completion(.finished),
                                                 .subscription("CustomSubscription"),
                                                 .subscription("CustomSubscription")])

        XCTAssertEqual(helper.subscription.history, [])

        XCTAssertEqual(subscription2.history, [.requested(.max(42)),
                                               .cancelled,
                                               .cancelled])
    }

    func testCrashesOnFailure() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(2),
                                        createSut: { $0.assertNoFailure() })
        helper.publisher.send(completion: .finished)
        assertCrashes {
            helper.publisher.send(completion: .failure(.oops))
        }
    }

    func testAssertNoFailureReflection() throws {
        try testReflection(
            parentInput: Int.self,
            parentFailure: TestingError.self,
            description: "AssertNoFailure",
            customMirror: expectedChildren(
                ("file", "SomeFile.swift"),
                ("line", "1987"),
                ("prefix", "PREFIX")
            ),
            playgroundDescription: "AssertNoFailure",
            subscriberIsAlsoSubscription: false,
            { $0.assertNoFailure("PREFIX", file: "SomeFile.swift", line: 1987) }
        )
    }
}
