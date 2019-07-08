//
//  AnySubjectTests.swift
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

@available(macOS 10.15, *)
final class AnySubjectTests: XCTestCase {

    static let allTests = [
        ("testEraseSubject", testEraseSubject),
        ("testClosureBasedSubject", testClosureBasedSubject),
    ]

    private typealias Sut = AnyPublisher<Int, TestingError>

    func testEraseSubject() {

        let subscriber = TrackingSubscriber()
        let subject = TrackingSubject<Int>(
            receiveSubscriber: {
                XCTAssertEqual($0.combineIdentifier, subscriber.combineIdentifier)
            }
        )
        let erased = AnySubject(subject)

        erased.subscribe(subscriber)
        erased.send(42)
        erased.send(completion: .finished)
        erased.send(completion: .failure("f"))
        erased.send(12)
        erased.subscribe(subscriber)

        XCTAssertEqual(subject.history, [.subscriber,
                                         .value(42),
                                         .completion(.finished),
                                         .completion(.failure("f")),
                                         .value(12),
                                         .subscriber])
    }

    func testClosureBasedSubject() {

        var events: [TrackingSubject<Int>.Event] = []

        let erased = AnySubject<Int, TestingError>(
            { _ in events.append(.subscriber) },
            { events.append(.value($0)) },
            { events.append(.completion($0)) }
        )
        let subscriber = TrackingSubscriber()

        erased.subscribe(subscriber)
        erased.send(42)
        erased.send(completion: .finished)
        erased.send(completion: .failure("f"))
        erased.send(12)
        erased.subscribe(subscriber)

        XCTAssertEqual(events, [.subscriber,
                                .value(42),
                                .completion(.finished),
                                .completion(.failure("f")),
                                .value(12),
                                .subscriber])
    }
}
