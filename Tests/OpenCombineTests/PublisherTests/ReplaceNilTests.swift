//
//  ReplaceNilTests.swift
//  
//
//  Created by Joseph Spadafora on 7/4/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class ReplaceNilTests: XCTestCase {
    static let allTests = [
        ("testReplacesNilElement", testReplacesNilElement),
        ("testExistingElementIsPreserved", testExistingElementIsPreserved),
        ("testMultipleReplacements", testMultipleReplacements)
    ]

    func testReplacesNilElement() {
        // Given
        let nilPublisher = PassthroughSubject<Int?, Never>()
        let output = Int.random(in: 1...100)
        let sut = nilPublisher.replaceNil(with: output)
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                $0.request(.unlimited)
            }
        )

        // When
        sut.subscribe(subscriber)
        nilPublisher.send(nil)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription("PassthroughSubject"),
                                            .value(output)])
    }

    func testExistingElementIsPreserved() {
        // Given
        let nilPublisher = PassthroughSubject<Int?, Never>()
        let output = Int.random(in: 1...100)
        let sut = nilPublisher.replaceNil(with: output + 1)
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                $0.request(.unlimited)
            }
        )

        // When
        sut.subscribe(subscriber)
        nilPublisher.send(output)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription("PassthroughSubject"),
                                            .value(output)])
    }

    func testMultipleReplacements() {
        // Given
        let passthrough = PassthroughSubject<Int?, Never>()
        let sut = passthrough.replaceNil(with: 42)
        let subscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                $0.request(.unlimited)
            }
        )

        // When
        sut.subscribe(subscriber)
        passthrough.send(1)
        passthrough.send(2)
        passthrough.send(nil)
        passthrough.send(4)
        passthrough.send(5)
        passthrough.send(nil)
        passthrough.send(completion: .finished)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription("PassthroughSubject"),
                                            .value(1),
                                            .value(2),
                                            .value(42),
                                            .value(4),
                                            .value(5),
                                            .value(42),
                                            .completion(.finished)])
    }
}
