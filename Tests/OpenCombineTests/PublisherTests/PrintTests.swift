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

@available(macOS 10.15, iOS 13.0, *)
final class PrintTests: XCTestCase {

    func testPrintWithoutPrefix() {

        let stream = HistoryStream()
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

        XCTAssertEqual(tracking.history, [.subscription("Print"),
                                          .value(1),
                                          .value(2),
                                          .completion(.finished),
                                          .completion(.failure("failure")),
                                          .value(10)])

        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .requested(.max(30)),
                                              .cancelled])

        let expectedOutput = [
            "",
            "receive subscription: (CustomSubscription)",
            "\n",
            "callback subscription\n",
            "",
            "request unlimited",
            "\n",
            "callback request demand\n",
            "",
            "request max: (30)",
            "\n",
            "callback request demand\n",
            "",
            "receive cancel",
            "\n",
            "callback cancel subscription\n",
            "",
            "receive value: (1)",
            "\n",
            "callback value\n",
            "",
            "request max: (100)",
            "\n",
            "",
            "request max: (2) (synchronous)",
            "\n",
            "",
            "request max: (42)",
            "\n",
            "",
            "receive value: (2)",
            "\n",
            "callback value\n",
            "",
            "request max: (100)",
            "\n",
            "",
            "request max: (2) (synchronous)",
            "\n",
            "",
            "receive finished",
            "\n",
            "callback completion\n",
            "",
            "request max: (12)",
            "\n",
            "",
            "receive error: (failure)",
            "\n",
            "callback completion\n",
            "",
            "request max: (12)",
            "\n",
            "",
            "receive value: (10)",
            "\n",
            "callback value\n",
            "",
            "request max: (100)",
            "\n",
            "",
            "request unlimited (synchronous)",
            "\n",
            "",
            "receive cancel",
            "\n"
        ]

        XCTAssertEqual(stream.output.value, expectedOutput)
    }

    func testPrintWithPrefix() {

        let stream = HistoryStream()
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

        XCTAssertEqual(tracking.history, [.subscription("Print"),
                                          .value(1),
                                          .value(2),
                                          .completion(.finished),
                                          .completion(.failure("failure")),
                                          .value(10)])

        XCTAssertEqual(subscription.history, [.requested(.unlimited),
                                              .requested(.max(30)),
                                              .cancelled])

        let expectedOutput = [
            "",
            "👉: receive subscription: (CustomSubscription)",
            "\n",
            "callback subscription\n",
            "",
            "👉: request unlimited",
            "\n",
            "callback request demand\n",
            "",
            "👉: request max: (30)",
            "\n",
            "callback request demand\n",
            "",
            "👉: receive cancel",
            "\n",
            "callback cancel subscription\n",
            "",
            "👉: receive value: (1)",
            "\n",
            "callback value\n",
            "",
            "👉: request max: (100)",
            "\n",
            "",
            "👉: request max: (2) (synchronous)",
            "\n",
            "",
            "👉: request max: (42)",
            "\n",
            "",
            "👉: receive value: (2)",
            "\n",
            "callback value\n",
            "",
            "👉: request max: (100)",
            "\n",
            "",
            "👉: request max: (2) (synchronous)",
            "\n",
            "",
            "👉: receive finished",
            "\n",
            "callback completion\n",
            "",
            "👉: request max: (12)",
            "\n",
            "",
            "👉: receive error: (failure)",
            "\n",
            "callback completion\n",
            "",
            "👉: request max: (12)",
            "\n",
            "",
            "👉: receive value: (10)",
            "\n",
            "callback value\n",
            "",
            "👉: request max: (100)",
            "\n",
            "",
            "👉: request unlimited (synchronous)",
            "\n",
            "",
            "👉: receive cancel",
            "\n"
        ]

        XCTAssertEqual(stream.output.value, expectedOutput)
    }

    func testSynchronization() {

        let stream = HistoryStream()
        let publisher = CustomPublisherBase<Int, Never>(subscription: nil)
        let printer = publisher.print(to: stream)

        let counter = Atomic(0)
        _ = printer.sink(receiveValue: { _ in counter.do { $0 += 1 } })

        race(
            { _ = publisher.send(12) },
            { _ = publisher.send(34) }
        )

        XCTAssertEqual(counter.value, 200)
    }
}

private final class HistoryStream: TextOutputStream {

    let output = Atomic([String]())

    func write(_ string: String) {
        output.do { $0.append(string) }
    }
}
