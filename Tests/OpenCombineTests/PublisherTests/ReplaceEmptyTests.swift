//
//  ReplaceEmptyTests.swift
//  OpenCombine
//
//  Created by Joseph Spadafora on 12/10/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ReplaceEmptyTests: XCTestCase {
    func testEmptySubscription() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 15) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty")])
    }

    func testError() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 42) }
        )

        helper.publisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .completion(.failure(.oops))])
    }

    func testEndWithoutValueReplacesCorrectly() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 42) }
        )

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(42),
                                                 .completion(.finished)])
    }

    func testNoValueIsReplacedIfEndsWithoutEmpty() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: .max(1),
                                        receiveValueDemand: .none,
                                        createSut: { $0.replaceEmpty(with: 42) }
        )

        XCTAssertEqual(helper.publisher.send(3), .none)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .value(3),
                                                 .completion(.finished)])
    }

  func testSendingValueAndThenError() {
      let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                      initialDemand: .max(1),
                                      receiveValueDemand: .max(1),
                                      createSut: { $0.replaceEmpty(with: 42) })

      XCTAssertEqual(helper.publisher.send(8), .max(1))
      helper.publisher.send(completion: .failure(TestingError.oops))

      XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                               .value(8),
                                               .completion(.failure(.oops))])
  }

    func testFailingBeforeDemanding() {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .max(1),
                                        createSut: { $0.replaceEmpty(with: 42) })

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty")])

        helper.publisher.send(completion: .failure(TestingError.oops))

        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .completion(.failure(.oops))])

        helper.downstreamSubscription?.request(.unlimited)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .completion(.failure(.oops))])

        XCTAssertEqual(helper.publisher.send(-1), .none)
        XCTAssertEqual(helper.tracking.history, [.subscription("ReplaceEmpty"),
                                                 .completion(.failure(.oops))])
    }
}
