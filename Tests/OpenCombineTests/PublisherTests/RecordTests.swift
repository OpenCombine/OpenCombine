//
//  RecordTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 12.11.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class RecordTests: XCTestCase {

    typealias Sut = Record<Int, TestingError>

    // MARK: - Record

    func testEmptyRecord() {

        let publisher = Sut { _ in }
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                XCTAssertEqual(String(describing: subscription), "Empty")
            }
        )
        publisher.subscribe(subscriber)
        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])

        var recording = publisher.recording
        recording.receive(0) // should not crash
        recording.receive(completion: .failure(.oops)) // should not crash

        XCTAssertEqual(publisher.recording.output, [])
        XCTAssertEqual(publisher.recording.completion, .finished)

        XCTAssertEqual(recording.output, [0])
        XCTAssertEqual(recording.completion, .failure(.oops))
    }

    func testEmptyRecordFinished() {

        let publisher = Sut { $0.receive(completion: .finished) }
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                XCTAssertEqual(String(describing: subscription), "Empty")
            }
        )
        publisher.subscribe(subscriber)
        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.finished)])
    }

    func testEmptyRecordFailed() {

        let publisher = Sut { $0.receive(completion: .failure(.oops)) }
        let subscriber = TrackingSubscriber(
            receiveSubscription: { subscription in
                XCTAssertEqual(String(describing: subscription), "Empty")
            }
        )
        publisher.subscribe(subscriber)
        XCTAssertEqual(subscriber.history, [.subscription("Empty"),
                                            .completion(.failure(.oops))])
    }

    func testRecordNoInitialDemand() throws {

        let publisher = Sut(output: [1, 2, 3, 4, 5, 6, 7, 8, 9], completion: .finished)
        let subscriber = TrackingSubscriber(
            receiveSubscription: {
                XCTAssertEqual(String(describing: $0), "[1, 2, 3, 4, 5, 6, 7, 8, 9]")
                expectedChildren(
                    ("sequence", "[1, 2, 3, 4, 5, 6, 7, 8, 9]"),
                    ("completion", .contains("finished"))
                )(Mirror(reflecting: $0))
            }
        )

        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("[1, 2, 3, 4, 5, 6, 7, 8, 9]")])

        subscriber.subscriptions.first?.request(.max(3))

        XCTAssertEqual(subscriber.history, [.subscription("[1, 2, 3, 4, 5, 6, 7, 8, 9]"),
                                            .value(1),
                                            .value(2),
                                            .value(3)])

        subscriber.subscriptions.first?.request(.max(5))

        XCTAssertEqual(subscriber.history, [.subscription("[1, 2, 3, 4, 5, 6, 7, 8, 9]"),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7),
                                            .value(8)])

        subscriber.subscriptions.first?.request(.none)

        XCTAssertEqual(subscriber.history, [.subscription("[1, 2, 3, 4, 5, 6, 7, 8, 9]"),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7),
                                            .value(8)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription("Cancelled Events"),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7),
                                            .value(8),
                                            .value(9),
                                            .completion(.finished)])

        expectedChildren(
            ("sequence", "[]"),
            ("completion", .contains("finished"))
        )(Mirror(reflecting: try XCTUnwrap(subscriber.subscriptions.first?.underlying)))
    }

    func testRecordInitialDemand() {
        let publisher = Sut(output: [1, 2, 3, 4, 5, 6, 7, 8, 9], completion: .finished)
        let subscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: {
                $0 > 4 || $0 == 1 ? .none : .max(2)
            }
        )

        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("[1, 2, 3, 4, 5, 6, 7, 8, 9]"),
                                            .value(1)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription("[1, 2, 3, 4, 5, 6, 7, 8, 9]"),
                                            .value(1),
                                            .value(2),
                                            .value(3),
                                            .value(4),
                                            .value(5),
                                            .value(6),
                                            .value(7),
                                            .value(8)])
    }

    func testCancelOnSubscription() {
        let publisher = Sut(output: [1, 2, 3, 4, 5, 6, 7, 8, 9], completion: .finished)
        let subscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(1)); $0.cancel() }
        )
        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Cancelled Events"),
                                            .value(1)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription("Cancelled Events"),
                                            .value(1)])
    }

    func testCancelOnValue() {
        let publisher = Sut(output: [1, 2, 3, 4, 5, 6, 7, 8, 9], completion: .finished)
        var subscription: Subscription?
        let subscriber = TrackingSubscriber(
            receiveSubscription: {
                subscription = $0
                $0.request(.unlimited)
            },
            receiveValue: { _ in
                subscription?.cancel()
                return .unlimited
            }
        )
        publisher.subscribe(subscriber)

        XCTAssertEqual(subscriber.history, [.subscription("Cancelled Events"),
                                            .value(1)])

        subscriber.subscriptions.first?.request(.max(1))

        XCTAssertEqual(subscriber.history, [.subscription("Cancelled Events"),
                                            .value(1)])
    }

    func testPublishesCorrectValuesThenFinishes() {
        let record = Sut(output: [1, 2, 3, 4, 5, 6, 7, 8, 9], completion: .finished)

        var history = [Int]()
        var completion: Subscribers.Completion<TestingError>?
        _ = record.sink(
            receiveCompletion: {
                XCTAssertEqual(history, [1, 2, 3, 4, 5, 6, 7, 8, 9])
                completion = $0
            },
            receiveValue: { history.append($0) }
        )

        XCTAssertEqual(history, [1, 2, 3, 4, 5, 6, 7, 8, 9])
        XCTAssertEqual(completion, .finished)
    }

    func testPublishesCorrectValuesThenFails() {
        let record = Sut(output: [1, 2, 3, 4, 5, 6, 7, 8, 9], completion: .failure(.oops))

        var history = [Int]()
        var completion: Subscribers.Completion<TestingError>?
        _ = record.sink(
            receiveCompletion: {
                XCTAssertEqual(history, [1, 2, 3, 4, 5, 6, 7, 8, 9])
                completion = $0
            },
            receiveValue: { history.append($0) }
        )

        XCTAssertEqual(history, [1, 2, 3, 4, 5, 6, 7, 8, 9])
        XCTAssertEqual(completion, .failure(.oops))
    }

    func testRecursion() {
        let sequence = Sut(output: [1, 2, 3, 4, 5], completion: .finished)

        var history = [Int]()
        var storedSubscription: Subscription?

        let tracking = TrackingSubscriber(
            receiveSubscription: { subscription in
                storedSubscription = subscription
                subscription.request(.none) // Shouldn't crash
                subscription.request(.max(1))
            },
            receiveValue: { value in
                storedSubscription?.request(.max(1))
                history.append(value)
                return .none
            }
        )

        sequence.subscribe(tracking)

        XCTAssertEqual(history, [1, 2, 3, 4, 5])
        XCTAssertEqual(tracking.history, [.subscription("Cancelled Events"),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .value(5),
                                          .completion(.finished)])
    }

    func testRecordEncodeEmpty() throws {
        let record = Sut(recording: .init())

        let encoder = TrackingEncoder()
        try record.encode(to: encoder)
        XCTAssertEqual(encoder.history, [.containerKeyedBy,
                                         .keyedContainerEncodeEncodable("recording"),
                                         .containerKeyedBy,
                                         .keyedContainerEncodeEncodable("output"),
                                         .unkeyedContainer,
                                         .keyedContainerEncodeEncodable("completion"),
                                         .containerKeyedBy,
                                         .keyedContainerEncodeBool(true, "success")])
    }

    func testRecordEncodeFinished() throws {
        let record = Sut(recording: .init(output: [3, 2, 1], completion: .finished))

        let encoder = TrackingEncoder()
        try record.encode(to: encoder)
        XCTAssertEqual(encoder.history, [.containerKeyedBy,
                                         .keyedContainerEncodeEncodable("recording"),
                                         .containerKeyedBy,
                                         .keyedContainerEncodeEncodable("output"),
                                         .unkeyedContainer,
                                         .unkeyedContainerEncodeEncodable,
                                         .singleValueContainer,
                                         .singleValueContainerEncodeInt(3),
                                         .unkeyedContainerEncodeEncodable,
                                         .singleValueContainer,
                                         .singleValueContainerEncodeInt(2),
                                         .unkeyedContainerEncodeEncodable,
                                         .singleValueContainer,
                                         .singleValueContainerEncodeInt(1),
                                         .keyedContainerEncodeEncodable("completion"),
                                         .containerKeyedBy,
                                         .keyedContainerEncodeBool(true, "success")])
    }

    func testRecordEncodeFailed() throws {
        let record =
            Sut(recording: .init(output: [3, 2, 1], completion: .failure(.oops)))

        let encoder = TrackingEncoder()
        try record.encode(to: encoder)
        XCTAssertEqual(encoder.history,
                       [.containerKeyedBy,
                        .keyedContainerEncodeEncodable("recording"),
                        .containerKeyedBy,
                        .keyedContainerEncodeEncodable("output"),
                        .unkeyedContainer,
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(3),
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(2),
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(1),
                        .keyedContainerEncodeEncodable("completion"),
                        .containerKeyedBy,
                        .keyedContainerEncodeBool(false, "success"),
                        .keyedContainerEncodeEncodable("error"),
                        .containerKeyedBy,
                        .keyedContainerEncodeString("oops", "description")])
    }

    func testRecordDecode() throws {
        let decoder = JSONDecoder()
        let validJSON = #"{"recording":{"completion":{"success":true},"output":[1,2]}}"#
        let invalidJSON = "{}"

        let record = try decoder
            .decode(Sut.self, from: Data(validJSON.utf8))

        XCTAssertEqual(record.recording.completion, .finished)
        XCTAssertEqual(record.recording.output, [1, 2])

        XCTAssertThrowsError(
            try decoder.decode(Sut.self, from: Data(invalidJSON.utf8))
        ) { error in
            switch error {
            case let DecodingError.keyNotFound(key, _):
                XCTAssertEqual(key.stringValue, "recording")
            default:
                XCTFail("DecodingError.keyNotFound error expected")
            }
        }
    }

    func testReflection() throws {
        try testSubscriptionReflection(description: "[1, 2]",
                                       customMirror: expectedChildren(
                                           ("sequence", "[1, 2]"),
                                           ("completion", .contains("finished"))
                                       ),
                                       playgroundDescription: "[1, 2]",
                                       sut: Sut(output: [1, 2], completion: .finished))

        try testSubscriptionReflection(description: "[1, 2]",
                                       customMirror: expectedChildren(
                                           ("sequence", "[1, 2]"),
                                           ("completion", .contains("failure(oops)"))
                                       ),
                                       playgroundDescription: "[1, 2]",
                                       sut: Sut(output: [1, 2],
                                                completion: .failure(.oops)))
    }

    func testLifecycle() throws {

        var deinitCounter = 0

        let onDeinit = {
            deinitCounter += 1
        }

        do {
            let publisher = Sut(output: [1, 2], completion: .finished)
            let subscriber = TrackingSubscriber(onDeinit: onDeinit)
            XCTAssertTrue(subscriber.history.isEmpty)

            publisher.subscribe(subscriber)
            XCTAssertEqual(subscriber.history, [.subscription("[1, 2]")])

            subscriber.subscriptions.first?.request(.max(3))
            XCTAssertEqual(subscriber.history, [.subscription("Cancelled Events"),
                                                .value(1),
                                                .value(2),
                                                .completion(.finished)])
        }

        XCTAssertEqual(deinitCounter, 1)

        var subscription: Subscription?

        do {
            let publisher = Sut(output: [1, 2], completion: .finished)
            let subscriber = TrackingSubscriber(
                receiveSubscription: { subscription = $0 },
                onDeinit: onDeinit
            )
            XCTAssertTrue(subscriber.history.isEmpty)
            publisher.subscribe(subscriber)
            XCTAssertEqual(subscriber.history, [.subscription("[1, 2]")])
            XCTAssertNotNil(subscription)
        }

        XCTAssertEqual(deinitCounter, 1)
        try XCTUnwrap(subscription).cancel()
        XCTAssertEqual(deinitCounter, 2)
    }

    // MARK: - Record.Recording

    func testRecordingBasicBehavior() {
        var recording = Sut.Recording()
        XCTAssertEqual(recording.output, [])
        XCTAssertEqual(recording.completion, .finished)

        recording.receive(1)
        recording.receive(2)
        recording.receive(1)
        recording.receive(10)

        XCTAssertEqual(recording.output, [1, 2, 1, 10])
        XCTAssertEqual(recording.completion, .finished)

        recording.receive(completion: .failure(.oops))

        XCTAssertEqual(recording.output, [1, 2, 1, 10])
        XCTAssertEqual(recording.completion, .failure(.oops))
    }

    func testRecordingCrashesIfReceivesValuesAfterCompletion() {
        var recording = Sut.Recording()
        recording.receive(completion: .finished)
        assertCrashes {
            recording.receive(42)
        }
    }

    func testRecordingCrashesIfReceivesCompletionTwice() {
        var recording = Sut.Recording()
        recording.receive(completion: .finished)
        assertCrashes {
            recording.receive(completion: .failure(.oops))
        }
    }

    func testRecordingEncodeEmpty() throws {
        let recording = Sut.Recording()

        let encoder1 = TrackingEncoder()
        try recording.encode(into: encoder1)
        XCTAssertEqual(encoder1.history, [.containerKeyedBy,
                                          .keyedContainerEncodeEncodable("output"),
                                          .unkeyedContainer,
                                          .keyedContainerEncodeEncodable("completion"),
                                          .containerKeyedBy,
                                          .keyedContainerEncodeBool(true, "success")])

        let encoder2 = TrackingEncoder()
        try recording.encode(to: encoder2)
        XCTAssertEqual(encoder2.history, [.containerKeyedBy,
                                          .keyedContainerEncodeEncodable("output"),
                                          .unkeyedContainer,
                                          .keyedContainerEncodeEncodable("completion"),
                                          .containerKeyedBy,
                                          .keyedContainerEncodeBool(true, "success")])
    }

    func testRecordingEncodeFinished() throws {
        let recording = Sut.Recording(output: [3, 2, 1], completion: .finished)

        let encoder1 = TrackingEncoder()
        try recording.encode(into: encoder1)
        XCTAssertEqual(encoder1.history, [.containerKeyedBy,
                                          .keyedContainerEncodeEncodable("output"),
                                          .unkeyedContainer,
                                          .unkeyedContainerEncodeEncodable,
                                          .singleValueContainer,
                                          .singleValueContainerEncodeInt(3),
                                          .unkeyedContainerEncodeEncodable,
                                          .singleValueContainer,
                                          .singleValueContainerEncodeInt(2),
                                          .unkeyedContainerEncodeEncodable,
                                          .singleValueContainer,
                                          .singleValueContainerEncodeInt(1),
                                          .keyedContainerEncodeEncodable("completion"),
                                          .containerKeyedBy,
                                          .keyedContainerEncodeBool(true, "success")])

        let encoder2 = TrackingEncoder()
        try recording.encode(to: encoder2)
        XCTAssertEqual(encoder2.history, [.containerKeyedBy,
                                          .keyedContainerEncodeEncodable("output"),
                                          .unkeyedContainer,
                                          .unkeyedContainerEncodeEncodable,
                                          .singleValueContainer,
                                          .singleValueContainerEncodeInt(3),
                                          .unkeyedContainerEncodeEncodable,
                                          .singleValueContainer,
                                          .singleValueContainerEncodeInt(2),
                                          .unkeyedContainerEncodeEncodable,
                                          .singleValueContainer,
                                          .singleValueContainerEncodeInt(1),
                                          .keyedContainerEncodeEncodable("completion"),
                                          .containerKeyedBy,
                                          .keyedContainerEncodeBool(true, "success")])
    }

    func testRecordingEncodeFailed() throws {
        let recording = Sut.Recording(output: [3, 2, 1], completion: .failure(.oops))

        let encoder1 = TrackingEncoder()
        try recording.encode(into: encoder1)
        XCTAssertEqual(encoder1.history,
                       [.containerKeyedBy,
                        .keyedContainerEncodeEncodable("output"),
                        .unkeyedContainer,
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(3),
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(2),
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(1),
                        .keyedContainerEncodeEncodable("completion"),
                        .containerKeyedBy,
                        .keyedContainerEncodeBool(false, "success"),
                        .keyedContainerEncodeEncodable("error"),
                        .containerKeyedBy,
                        .keyedContainerEncodeString("oops", "description")])

        let encoder2 = TrackingEncoder()
        try recording.encode(to: encoder2)
        XCTAssertEqual(encoder2.history,
                       [.containerKeyedBy,
                        .keyedContainerEncodeEncodable("output"),
                        .unkeyedContainer,
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(3),
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(2),
                        .unkeyedContainerEncodeEncodable,
                        .singleValueContainer,
                        .singleValueContainerEncodeInt(1),
                        .keyedContainerEncodeEncodable("completion"),
                        .containerKeyedBy,
                        .keyedContainerEncodeBool(false, "success"),
                        .keyedContainerEncodeEncodable("error"),
                        .containerKeyedBy,
                        .keyedContainerEncodeString("oops", "description")])
    }

    func testRecordingDecode() throws {
        let decoder = JSONDecoder()
        let validJSON = #"{"completion":{"success":true},"output":[1,2]}"#
        let invalidJSON1 = #"{"completion":{"success":true}}"#
        let invalidJSON2 = #"{"output":[1,2]}"#

        let recording = try decoder
            .decode(Sut.Recording.self, from: Data(validJSON.utf8))

        XCTAssertEqual(recording.completion, .finished)
        XCTAssertEqual(recording.output, [1, 2])

        XCTAssertThrowsError(
            try decoder.decode(Sut.Recording.self, from: Data(invalidJSON1.utf8))
        ) { error in
            switch error {
            case let DecodingError.keyNotFound(key, _):
                XCTAssertEqual(key.stringValue, "output")
            default:
                XCTFail("DecodingError.keyNotFound error expected")
            }
        }

        XCTAssertThrowsError(
            try decoder.decode(Sut.Recording.self, from: Data(invalidJSON2.utf8))
        ) { error in
            switch error {
            case let DecodingError.keyNotFound(key, _):
                XCTAssertEqual(key.stringValue, "completion")
            default:
                XCTFail("DecodingError.keyNotFound error expected")
            }
        }
    }

    func testRecordingIsDecodedInFinalizedState() throws {
        let decoder = JSONDecoder()
        let json = #"{"completion":{"success":true},"output":[1,2]}"#
        var recording = try decoder.decode(Sut.Recording.self, from: Data(json.utf8))

        assertCrashes {
            recording.receive(42)
        }
    }
}
