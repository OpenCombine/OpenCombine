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

@available(macOS 10.15, *)
final class ReplaceNilTests: XCTestCase {
    static let allTests = [
        ("testReturnsMapPublisher", testReturnsMapPublisher),
        ("testReplacesNilElement", testReplacesNilElement),
        ("testExistingElementIsPreserved", testExistingElementIsPreserved)
    ]

    func testReturnsMapPublisher() {
        // Given
        let nilPublisher = PassthroughSubject<Int?, Never>()

        // When
        let replaceNil = nilPublisher.replaceNil(with: 42)

        // Then
        let mirror = Mirror(reflecting: replaceNil)
        let expected = "Mirror for Map<PassthroughSubject<Optional<Int>, Never>, Int>"
        XCTAssertEqual(mirror.description, expected)
    }

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
        sut.receive(subscriber: subscriber)
        nilPublisher.send(nil)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
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
        sut.receive(subscriber: subscriber)
        nilPublisher.send(output)

        // Then
        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .value(output)])
    }
}
