//
//  PrintTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class PrintTests: XCTestCase {

    static let allTests = [
        ("testPrintWithoutPrefix", testPrintWithoutPrefix),
        ("testPrintWithPrefix", testPrintWithPrefix),
        ("testSynchronization", testSynchronization),
    ]

    func testPrintWithoutPrefix() {

        let stream = StringStream()
        let subscription = CustomSubscription(
            onRequest: { _ in stream.write("callback request demand\n") },
            onCancel: { stream.write("callback cancel subscription\n") }
        )
        var downstreamSubscription: Subscription?
        let publisher = CustomPublisher(subscription: subscription)
        let printer = publisher.print(to: stream)
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                stream.write("callback subscription\n")
                $0.request(.unlimited)
                $0.request(.max(30))
                $0.cancel()
                downstreamSubscription = $0
            },
            receiveValue: {
                stream.write("callback value\n")
                downstreamSubscription?.request(.max(100))
                return $0 == 10 ? .unlimited : .max(2)
            },
            receiveCompletion: { _ in
                stream.write("callback completion\n")
                downstreamSubscription?.request(.max(12))
            }
        )

        printer.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(publisher.send(1), .max(2))
        downstreamSubscription?.request(.max(42))
        XCTAssertEqual(publisher.send(2), .max(2))
        publisher.send(completion: .finished)
        publisher.send(completion: .failure("failure"))
        XCTAssertEqual(publisher.send(10), .unlimited)
        downstreamSubscription?.cancel()

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(1),
                                          .value(2),
                                          .completion(.finished),
                                          .completion(.failure("failure")),
                                          .value(10)])

        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .requested(.max(30)),
                                              .canceled])

        let expectedOutput = """
        receive subscription: (OpenCombineTests.CustomSubscription)
        callback subscription
        request unlimited
        callback request demand
        request max: (30)
        callback request demand
        receive cancel
        callback cancel subscription
        receive value: (1)
        callback value
        request max: (100)
        request max: (2) (synchronous)
        request max: (42)
        receive value: (2)
        callback value
        request max: (100)
        request max: (2) (synchronous)
        receive finished
        callback completion
        request max: (12)
        receive error: (failure)
        callback completion
        request max: (12)
        receive value: (10)
        callback value
        request max: (100)
        request unlimited (synchronous)
        receive cancel

        """

        XCTAssertEqual(stream.output.value, expectedOutput)
    }

    func testPrintWithPrefix() {

        let stream = StringStream()
        let subscription = CustomSubscription(
            onRequest: { _ in stream.write("callback request demand\n") },
            onCancel: { stream.write("callback cancel subscription\n") }
        )
        var downstreamSubscription: Subscription?
        let publisher = CustomPublisher(subscription: subscription)
        let printer = publisher.print("👉", to: stream)
        let tracking = TrackingSubscriber(
            receiveSubscription: {
                stream.write("callback subscription\n")
                $0.request(.unlimited)
                $0.request(.max(30))
                $0.cancel()
                downstreamSubscription = $0
        },
            receiveValue: {
                stream.write("callback value\n")
                downstreamSubscription?.request(.max(100))
                return $0 == 10 ? .unlimited : .max(2)
        },
            receiveCompletion: { _ in
                stream.write("callback completion\n")
                downstreamSubscription?.request(.max(12))
        }
        )

        printer.subscribe(tracking)

        XCTAssertNotNil(downstreamSubscription)

        XCTAssertEqual(publisher.send(1), .max(2))
        downstreamSubscription?.request(.max(42))
        XCTAssertEqual(publisher.send(2), .max(2))
        publisher.send(completion: .finished)
        publisher.send(completion: .failure("failure"))
        XCTAssertEqual(publisher.send(10), .unlimited)
        downstreamSubscription?.cancel()

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(1),
                                          .value(2),
                                          .completion(.finished),
                                          .completion(.failure("failure")),
                                          .value(10)])

        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .requested(.max(30)),
                                              .canceled])

        let expectedOutput = """
        👉: receive subscription: (OpenCombineTests.CustomSubscription)
        callback subscription
        👉: request unlimited
        callback request demand
        👉: request max: (30)
        callback request demand
        👉: receive cancel
        callback cancel subscription
        👉: receive value: (1)
        callback value
        👉: request max: (100)
        👉: request max: (2) (synchronous)
        👉: request max: (42)
        👉: receive value: (2)
        callback value
        👉: request max: (100)
        👉: request max: (2) (synchronous)
        👉: receive finished
        callback completion
        👉: request max: (12)
        👉: receive error: (failure)
        callback completion
        👉: request max: (12)
        👉: receive value: (10)
        callback value
        👉: request max: (100)
        👉: request unlimited (synchronous)
        👉: receive cancel

        """

        XCTAssertEqual(stream.output.value, expectedOutput)
    }

    func testSynchronization() {

        let stream = StringStream()
        let publisher = CustomPublisher(subscription: nil)
        let printer = publisher.print(to: stream)

        let counter = Atomic(0)
        _ = printer.sink(receiveValue: { _ in counter.do { $0 += 1 }})

        race(
            { _ = publisher.send(12) },
            { _ = publisher.send(34) }
        )

        XCTAssertEqual(counter.value, 200)
    }
}

private final class StringStream: TextOutputStream {
    var output = Atomic("")
    func write(_ string: String) {
        output.do { $0.write(string) }
    }
}
