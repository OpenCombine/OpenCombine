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

@available(macOS 10.15, iOS 13.0, *)
private typealias Sut = AnySubscriber<Int, TestingError>

@available(macOS 10.15, iOS 13.0, *)
final class AnySubscriberTests: XCTestCase {

    func testCombineIdentifier() {

        let empty = Sut()
        XCTAssertEqual(empty.combineIdentifier.description,
                       empty.combineIdentifier.description,
                       "combineIdentifier shouldn't change")

        let subscriber1 = TrackingSubscriber()
        let subscriber2 = TrackingSubscriber()

        do {
            let erased1 = Sut(subscriber1)
            let erased2 = Sut(subscriber2)
            XCTAssertNotEqual(erased1.combineIdentifier, erased2.combineIdentifier)
        }

        do {
            let subject = Sut(subscriber1)
            XCTAssertEqual(subscriber1.combineIdentifier, subject.combineIdentifier)
        }

        do {
            let subject = Sut(subscriber2)
            XCTAssertEqual(subscriber2.combineIdentifier, subject.combineIdentifier)
        }
    }

    func testDescription() {

        let empty = Sut()
        XCTAssertEqual(empty.description, "Anonymous AnySubscriber")
        XCTAssertEqual(empty.description, empty.playgroundDescription as? String)

        let subject = PassthroughSubject<Int, TestingError>()
        let erasingSubject = Sut(subject)
        XCTAssertEqual(erasingSubject.description, "Subject")
        XCTAssertEqual(erasingSubject.description,
                       erasingSubject.playgroundDescription as? String)

        let subscriber = TrackingSubscriber()
        let erasingSubscriber = Sut(subscriber)
        XCTAssertEqual(erasingSubscriber.description,
                       "TrackingSubscriberBase<Int, TestingError>: []")
        XCTAssertEqual(erasingSubscriber.description,
                       erasingSubscriber.playgroundDescription as? String)
    }

    func testReflection() {

        let empty = Sut()
        XCTAssertEqual(
            String(describing: Mirror(reflecting: empty).subjectType),
            "String"
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
            "TrackingSubscriberBase<Int, TestingError>"
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

        XCTAssertEqual(subscriber.history, [.subscription("PassthroughSubject"),
                                            .completion(.finished)])
    }

    func testErasingSubject() {

        let subject = TrackingSubject<Int>()
        XCTAssert(subject.history.isEmpty)

        let erased = Sut(subject)

        publishEvents(events, erased)

        let expectedEvents: [TrackingSubject<Int>.Event] =
            [.subscription("Subject")] + events.compactMap(subscriberEventToSubjectEvent)
                .throughFirstCompletion()

        XCTAssertEqual(subject.history, expectedEvents)

        let demand = erased.receive(0)

        XCTAssertEqual(demand, .none)
    }

    func testErasingSubjectSubscription() {

        let subject = TrackingSubject<Int>()
        XCTAssert(subject.history.isEmpty)

        let erased = Sut(subject)

        let publisher = PassthroughSubject<Int, TestingError>()
        publisher.subscribe(erased)

        publishEvents(events, publisher)

        XCTAssertEqual(subject.history, [.subscription("Subject"),
                                         .completion(.finished)])
    }

    @available(macOS 11.0, iOS 14.0, *)
    func testErasingTwice() {
        let introspection = TrackingIntrospection()
        let subscriber = TrackingSubscriber()
        let publisher = PassthroughSubject<Int, TestingError>()
        let erasedTwice = Sut(Sut(subscriber))

        introspection.temporarilyEnable {
            publisher.subscribe(erasedTwice)
        }

        XCTAssertEqual(subscriber.history, [.subscription("PassthroughSubject")])
        XCTAssertEqual(
            introspection.history,
            [.publisherWillReceiveSubscriber(.init(publisher), .init(subscriber)),
             .subscriberWillReceiveSubscription(.init(subscriber), "PassthroughSubject"),
             .subscriberDidReceiveSubscription(.init(subscriber), "PassthroughSubject"),
             .publisherDidReceiveSubscriber(.init(publisher), .init(subscriber))]
        )
    }
}

@available(macOS 10.15, iOS 13.0, *)
private let events: [TrackingSubscriber.Event] = [
    .subscription("1"),
    .subscription("2"),
    .subscription("3"),
    .value(31),
    .value(42),
    .value(-1),
    .value(141241241),
    .completion(.finished),
    .completion(.finished),
    .completion(.failure("failure"))
]

@available(macOS 10.15, iOS 13.0, *)
private func publishEvents(_ events: [TrackingSubscriber.Event], _ erased: Sut) {
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

@available(macOS 10.15, iOS 13.0, *)
private func publishEvents(
    _ events: [TrackingSubscriber.Event],
    _ publisher: PassthroughSubject<Int, TestingError>
) {
    for event in events {
        switch event {
        case .subscription(let s):
            publisher.send(subscription: s)
        case .value(let v):
            publisher.send(v)
        case .completion(let c):
            publisher.send(completion: c)
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
private func subscriberEventToSubjectEvent(
    _ from: TrackingSubscriber.Event
) -> TrackingSubject<Int>.Event? {
    switch from {
    case .subscription:
        return nil
    case let .value(v):
        return .value(v)
    case let .completion(c):
        return .completion(c)
    }
}

@available(macOS 10.15, iOS 13.0, *)
extension Array {
    func throughFirstCompletion<SubjectOutput>() -> Array
        where Element == TrackingSubject<SubjectOutput>.Event
    {
        var encounteredFirstCompletion = false
        return self.prefix {
            if encounteredFirstCompletion {
                return false
            }
            if case .completion = $0 {
                encounteredFirstCompletion = true
            }
            return true
        }
    }
}
