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

        let subject = TrackingSubject()
        let erased = AnySubject(subject)
        let subscriber = TrackingSubscriber()

        erased.receive(subscriber: subscriber)
        erased.send(42)
        erased.send(completion: .finished)
        erased.send(completion: .failure("f"))
        erased.send(12)
        erased.receive(subscriber: subscriber)

        XCTAssertEqual(subject.history, [.subscriber(subscriber.combineIdentifier),
                                         .value(42),
                                         .completion(.finished),
                                         .completion(.failure("f")),
                                         .value(12),
                                         .subscriber(subscriber.combineIdentifier)])
    }

    func testClosureBasedSubject() {

        var events: [TrackingSubject.Event] = []

        let erased = AnySubject<Int, TestingError>(
            { events.append(.subscriber($0.combineIdentifier)) },
            { events.append(.value($0)) },
            { events.append(.completion($0)) }
        )
        let subscriber = TrackingSubscriber()

        erased.receive(subscriber: subscriber)
        erased.send(42)
        erased.send(completion: .finished)
        erased.send(completion: .failure("f"))
        erased.send(12)
        erased.receive(subscriber: subscriber)

        XCTAssertEqual(events, [.subscriber(subscriber.combineIdentifier),
                                .value(42),
                                .completion(.finished),
                                .completion(.failure("f")),
                                .value(12),
                                .subscriber(subscriber.combineIdentifier)])
    }
}
