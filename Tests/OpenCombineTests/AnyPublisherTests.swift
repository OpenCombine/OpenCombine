//
//  AnyPublisherTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class AnyPublisherTests: XCTestCase {

    static let allTests = [
        ("testErasePublisher", testErasePublisher),
        ("testDescription", testDescription),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    private typealias Sut = AnyPublisher<Int, TestingError>

    func testErasePublisher() {

        let subscriber = TrackingSubscriber()
        let publisher = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual($0.combineIdentifier, subscriber.combineIdentifier)
            }
        )
        let erased = AnyPublisher(publisher)

        erased.subscribe(subscriber)
        XCTAssertEqual(publisher.history, [.subscriber])
    }

    func testDescription() {
        let erased = AnyPublisher(TrackingSubject<Int>())
        XCTAssertEqual(erased.description, "AnyPublisher")
        XCTAssertEqual(erased.description, erased.playgroundDescription as? String)
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
