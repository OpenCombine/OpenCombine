//
//  EncodeTests.swift
//
//
//  Created by Joseph Spadafora on 6/21/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class EncodeTests: XCTestCase {

    private var encoder = TestEncoder()
    private var decoder = TestDecoder()

    override func setUp() {
        super.setUp()
        encoder = TestEncoder()
        decoder = TestDecoder()
    }

    // MARK: - Encode

    func testEncodingSuccess() throws {

        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<[String : String], Error>.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: { $0.encode(encoder: encoder) })

        XCTAssertEqual(helper.publisher.send(["test": "test1"]), .none)
        XCTAssertEqual(helper.publisher.send(["test": "test2"]), .none)

        XCTAssertEqual(encoder.encoded[1] as? [String : String], ["test": "test1"])
        XCTAssertEqual(encoder.encoded[2] as? [String : String], ["test": "test2"])

        XCTAssertEqual(helper.tracking.history, [.subscription("Encode"),
                                                 .value(1),
                                                 .value(2)])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription("Encode"),
                                                 .value(1),
                                                 .value(2),
                                                 .completion(.finished)])

        XCTAssertEqual(helper.publisher.send(testValue), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Encode"),
                                                 .value(1),
                                                 .value(2),
                                                 .completion(.finished)])
    }

    func testEncodingFailure() throws {
        encoder.handleEncode = { _ in throw TestingError.oops }
        try EncodeTests.testCodingFailure(expectedSubscription: "Encode",
                                          { $0.encode(encoder: encoder) })
    }

    func testEncodeSuccessHistory() throws {
        let subject = PassthroughSubject<[String : String], Error>()
        let publisher = subject.encode(encoder: encoder)
        let subscriber = TrackingSubscriberBase<Int, Error>(
            receiveSubscription: { $0.request(.unlimited) }
        )

        publisher.subscribe(subscriber)
        subject.send(testValue)

        guard let testKey = encoder.encoded.first?.key, encoder.encoded.count == 1 else {
            XCTFail("Could not get testing data from encoding")
            return
        }
        XCTAssertEqual(subscriber.history, [.subscription("Encode"),
                                            .value(testKey)])
    }

    func testEncodeDemand() throws {
        try EncodeTests.testDemand {
            $0.encode(encoder: encoder)
        }
    }

    func testEncodeReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice { $0.encode(encoder: encoder) }
    }

    func testEncodeCancelsSubscriptionThenReleasesIt() throws {
        try EncodeTests.testCancelsSubscriptionThenReleasesIt(
            expectedSubscription: "Encode",
            { $0.encode(encoder: encoder) }
        )
    }

    func testEncodeCompletionReleasesUpstreamSubscription() throws {
        try EncodeTests.testCompletionReleasesUpstreamSubscription(
            expectedSubscription: "Encode",
            { $0.encode(encoder: encoder) }
        )
    }

    func testEncodeCancellingSubscriptionPreventsDeliveringToDownstream() throws {
        try EncodeTests.testCancellingSubscriptionPreventsDeliveringToDownstream(
            expectedSubscription: "Encode",
            { $0.encode(encoder: encoder) }
        )
    }

    func testEncodeReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(1)],
                                                              demand: .max(42)),
                                           { $0.encode(encoder: encoder) })
    }

    func testEncodeReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.encode(encoder: encoder) }
        )
    }

    func testEncodeRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.encode(encoder: encoder) })
    }

    func testEncodeCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.encode(encoder: encoder) })
    }

    func testEncodeLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.encode(encoder: TestEncoder()) })
    }

    func testEncodeReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Encode",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("finished", "false"),
                               ("upstreamSubscription", .anything)
                           ),
                           playgroundDescription: "Encode",
                           { $0.encode(encoder: encoder) })
    }

    // MARK: - Decode

    func testDecodingSuccess() throws {
        decoder.handleDecode = { ["key\($0)" : "value\($0)"] }

        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: { $0.decode(type: [String : String].self, decoder: decoder) })

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Decode"),
                                                 .value(["key1" : "value1"]),
                                                 .value(["key2" : "value2"])])

        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.publisher.send(3), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Decode"),
                                                 .value(["key1" : "value1"]),
                                                 .value(["key2" : "value2"]),
                                                 .completion(.finished)])
    }

    func testDecodingFailure() throws {
        decoder.handleDecode = { _ in throw TestingError.oops }
        try EncodeTests.testCodingFailure(
            expectedSubscription: "Decode",
            { $0.decode(type: [String : String].self, decoder: decoder) }
        )
    }

    func testDecodeDemand() throws {
        decoder.handleDecode = { _ in testValue }
        try EncodeTests.testDemand {
            $0.decode(type: [String : String].self, decoder: decoder)
        }
    }

    func testDecodeReceiveSubscriptionTwice() throws {
        try testReceiveSubscriptionTwice {
            $0.decode(type: [String : String].self, decoder: decoder)
        }
    }

    func testDecodeCancelsSubscriptionThenReleasesIt() throws {
        decoder.handleDecode = { _ in testValue }
        try EncodeTests.testCancelsSubscriptionThenReleasesIt(
            expectedSubscription: "Decode",
            { $0.decode(type: [String : String].self, decoder: decoder) }
        )
    }

    func testDecodeCompletionReleasesUpstreamSubscription() throws {
        decoder.handleDecode = { _ in testValue }
        try EncodeTests.testCompletionReleasesUpstreamSubscription(
            expectedSubscription: "Decode",
            { $0.decode(type: [String : String].self, decoder: decoder) }
        )
    }

    func testDecodeCancellingSubscriptionPreventsDeliveringToDownstream() throws {
        decoder.handleDecode = { _ in testValue }
        try EncodeTests.testCancellingSubscriptionPreventsDeliveringToDownstream(
            expectedSubscription: "Decode",
            { $0.decode(type: [String : String].self, decoder: decoder) }
        )
    }

    func testDecodeReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([.completion(.failure(TestDecoder.error))], demand: .none),
            { $0.decode(type: String.self, decoder: decoder) }
        )
    }

    func testDecodeReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.decode(type: String.self, decoder: decoder) }
        )
    }

    func testDecodeRequestBeforeSubscription() {
        testRequestBeforeSubscription(inputType: Int.self,
                                      shouldCrash: false,
                                      { $0.decode(type: String.self, decoder: decoder) })
    }

    func testDecodeCancelBeforeSubscription() {
        testCancelBeforeSubscription(inputType: Int.self,
                                     expected: .history([]),
                                     { $0.decode(type: String.self, decoder: decoder) })
    }

    func testDecodeLifecycle() throws {
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          { $0.decode(type: Int.self, decoder: decoder) })
    }

    func testDecodeReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Error.self,
                           description: "Decode",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("finished", "false"),
                               ("upstreamSubscription", .anything)
                           ),
                           playgroundDescription: "Decode",
                           { $0.decode(type: Int.self, decoder: decoder) })
    }

    // MARK: - Generic tests

    private static func testCodingFailure<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisher) -> Operator
    ) throws where Operator.Output: Equatable, Operator.Failure == Error {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: makeOperator
        )

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        helper.subscription.onCancel = {
            helper.downstreamSubscription?.request(.max(42))

            XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
        }

        helper.tracking.onFailure = { error in
            XCTAssertEqual(helper.tracking.history,
                           [.subscription(expectedSubscription),
                            .completion(.failure(error))])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
        }

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)

        XCTAssertEqual(helper.tracking.history,
                       [.subscription(expectedSubscription),
                        .completion(.failure(TestingError.oops))])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                     .cancelled])
    }

    private static func testDemand<Operator: Publisher>(
        _ makeOperator: (CustomPublisherBase<Int, Error>) -> Operator
    ) throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisherBase<Int, Error>.self,
            initialDemand: .max(37),
            receiveValueDemand: .max(2),
            createSut: makeOperator
        )

        XCTAssertEqual(helper.publisher.send(37), .max(2))
        XCTAssertEqual(helper.subscription.history, [.requested(.max(37))])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.publisher.send(42), .none)
        XCTAssertEqual(helper.subscription.history, [.requested(.max(37)), .cancelled])
    }

    private static func testReceiveSubscriptionTwice<Operator: Publisher>(
        _ makeOperator: (CustomPublisher) -> Operator
    ) throws where Operator.Output: Equatable {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: makeOperator
        )

        XCTAssertEqual(helper.subscription.history, [])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.cancelled, .cancelled])

        let thirdSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)

        XCTAssertEqual(thirdSubscription.history, [.cancelled])
    }

    private static func testCancelsSubscriptionThenReleasesIt<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisher) -> Operator
    ) throws where Operator.Output: Equatable {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: makeOperator)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [])

        var recursionDepth = 0
        helper.subscription.onCancel = {
            if recursionDepth >= 5 { return }
            recursionDepth += 1
            helper.downstreamSubscription?.cancel()
        }

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(recursionDepth, 1)
    }

    private static func testCancellingSubscriptionPreventsDeliveringToDownstream<
        Operator: Publisher
    >(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisher) -> Operator
    ) throws where Operator.Output: Equatable {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: makeOperator)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [])

        try XCTUnwrap(helper.downstreamSubscription).cancel()
        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.cancelled])

        XCTAssertEqual(helper.publisher.send(42), .none)
        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [.cancelled])
    }

    private static func testCompletionReleasesUpstreamSubscription<Operator: Publisher>(
        expectedSubscription: StringSubscription,
        _ makeOperator: (CustomPublisher) -> Operator
    ) throws where Operator.Output: Equatable {
        let helper = OperatorTestHelper(publisherType: CustomPublisher.self,
                                        initialDemand: nil,
                                        receiveValueDemand: .none,
                                        createSut: makeOperator)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription)])
        XCTAssertEqual(helper.subscription.history, [])

        helper.publisher.send(completion: .finished)
        helper.publisher.send(completion: .finished)

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))
        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))

        XCTAssertEqual(helper.tracking.history, [.subscription(expectedSubscription),
                                                 .completion(.finished)])
        XCTAssertEqual(helper.subscription.history, [])
    }
}

private let testValue = ["test": "TestDecodable"]
