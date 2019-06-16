//
//  AnySubscriberTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

private typealias Sut = AnySubscriber<Int, TestingError>

@available(macOS 10.15, *)
final class AnySubscriberTests: XCTestCase {

    static let allTests = [
        ("testCombineIdentifier", testCombineIdentifier),
        ("testDescription", testDescription),
        ("testReflection", testReflection),
        ("testErasingSubscriber", testErasingSubscriber),
        ("testErasingSubscriberSubscription", testErasingSubscriberSubscription),
        ("testErasingSubject", testErasingSubject),
        ("testErasingSubjectSubscription", testErasingSubjectSubscription),
    ]

    func testCombineIdentifier() {

        let empty = Sut()
        XCTAssertEqual(empty.combineIdentifier.description,
                       empty.combineIdentifier.description,
                       "combineIdentifier shouldn't change")

        let subscriber1 = TrackingSubscriber()
        let subscriber2 = TrackingSubscriber()
        XCTAssertNotEqual(Sut(subscriber1).combineIdentifier,
                          Sut(subscriber2).combineIdentifier)
        XCTAssertEqual(subscriber1.combineIdentifier,
                       Sut(subscriber1).combineIdentifier)
        XCTAssertEqual(subscriber2.combineIdentifier,
                       Sut(subscriber2).combineIdentifier)
    }

    func testDescription() {

        let empty = Sut()
        XCTAssertEqual(empty.description, "AnySubscriber")
        XCTAssertEqual(empty.description, empty.playgroundDescription as? String)

        let subject = PassthroughSubject<Int, TestingError>()
        let erasingSubject = Sut(subject)
        XCTAssertEqual(erasingSubject.description, "Subject")
        XCTAssertEqual(erasingSubject.description,
                       erasingSubject.playgroundDescription as? String)

        let subscriber = TrackingSubscriber()
        let erasingSubscriber = Sut(subscriber)
        XCTAssertEqual(erasingSubscriber.description,
                       "TrackingSubscriberBase<TestingError>: []")
        XCTAssertEqual(erasingSubscriber.description,
                       erasingSubscriber.playgroundDescription as? String)
    }

    func testReflection() {

        let empty = Sut()
        XCTAssertEqual(
            String(describing: Mirror(reflecting: empty).subjectType),
            "CombineIdentifier"
        )
        XCTAssert(Mirror(reflecting: empty).children.isEmpty)

        let subject = PassthroughSubject<Int, TestingError>()
        let erasingSubject = Sut(subject)
        XCTAssertEqual(
            String(describing: Mirror(reflecting: erasingSubject).subjectType),
            "SubjectSubscriber<PassthroughSubject<Int, TestingError>>"
        )
        XCTAssertFalse(Mirror(reflecting: erasingSubject).children.isEmpty)

        let subscriber = TrackingSubscriber()
        let erasingSubscriber = Sut(subscriber)
        XCTAssertEqual(
            String(describing: Mirror(reflecting: erasingSubscriber).subjectType),
            "TrackingSubscriberBase<TestingError>"
        )
    }

    func testErasingSubscriber() {

        let subscriber = TrackingSubscriber()
        XCTAssert(subscriber.history.isEmpty)

        let erased = Sut(subscriber)

        // AnySubscriber should just forward calls to the underlying subscriber

        publishEvents(events, erased)

        XCTAssertEqual(subscriber.history, events)

        let shuffledEvents = events.shuffled()

        publishEvents(shuffledEvents, erased)

        XCTAssertEqual(subscriber.history, events + shuffledEvents)
    }

    func testErasingSubscriberSubscription() {

        let subscriber = TrackingSubscriber()
        XCTAssert(subscriber.history.isEmpty)

        let erased = Sut(subscriber)

        let publisher = PassthroughSubject<Int, TestingError>()
        publisher.subscribe(erased)

        publishEvents(events, publisher)

        XCTAssertEqual(subscriber.history, [.subscription(Subscriptions.empty),
                                            .completion(.finished)])
    }

    func testErasingSubject() {

        let subject = TrackingSubject()
        XCTAssert(subject.history.isEmpty)

        let erased = Sut(subject)

        publishEvents(events, erased)

        let expectedEvents: [TrackingSubject.Event] =
            events.compactMap(subscriberEventToSubjectEvent)

        XCTAssertEqual(subject.history, expectedEvents)

        let shuffledEvents = events.shuffled()

        publishEvents(shuffledEvents, erased)

        let expectedShuffledEvents =
            shuffledEvents.compactMap(subscriberEventToSubjectEvent)

        XCTAssertEqual(subject.history, expectedEvents + expectedShuffledEvents)

        let demand = erased.receive(0)

        XCTAssertEqual(demand, .none)
    }

    func testErasingSubjectSubscription() {

        let subject = TrackingSubject()
        XCTAssert(subject.history.isEmpty)

        let erased = Sut(subject)

        let publisher = PassthroughSubject<Int, TestingError>()
        publisher.subscribe(erased)

        publishEvents(events, publisher)

        XCTAssertEqual(subject.history, [.value(31),
                                         .value(42),
                                         .value(-1),
                                         .value(141241241),
                                         .completion(.finished)])
    }
}

@available(OSX 10.15, *)
private let events: [TrackingSubscriber.Event] = [
    .subscription(Subscriptions.empty),
    .subscription(Subscriptions.empty),
    .subscription(Subscriptions.empty),
    .value(31),
    .value(42),
    .value(-1),
    .value(141241241),
    .completion(.finished),
    .completion(.finished),
    .completion(.failure("failure"))
]

@available(OSX 10.15, *)
private func publishEvents(_ events: [TrackingSubscriber.Event],_ erased: Sut) {
    for event in events {
        switch event {
        case .subscription(let s):
            erased.receive(subscription: s)
        case .value(let v):
            _ = erased.receive(v)
        case .completion(let c):
            erased.receive(completion: c)
        }
    }
}

@available(OSX 10.15, *)
private func publishEvents(
    _ events: [TrackingSubscriber.Event],
    _ publisher: PassthroughSubject<Int, TestingError>
) {
    for event in events {
        switch event {
        case .subscription:
            break
        case .value(let v):
            publisher.send(v)
        case .completion(let c):
            publisher.send(completion: c)
        }
    }
}


@available(OSX 10.15, *)
private func subscriberEventToSubjectEvent(
    _ from: TrackingSubscriber.Event
) -> TrackingSubject.Event? {
    switch from {
    case .subscription:
        return nil
    case let .value(v):
        return .value(v)
    case let .completion(c):
        return .completion(c)
    }
}
