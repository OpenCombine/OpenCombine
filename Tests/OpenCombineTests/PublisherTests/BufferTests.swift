//
//  BufferTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.01.2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class BufferTests: XCTestCase {

    func testInitialDemandWithKeepFullPrefetchStrategy() {
        testInitialDemand(
            withPrefetchStrategy: .keepFull,
            expectedSubscriptionHistory: [.requested(.max(42))]
        )
    }

    func testInitialDemandWithByRequestPrefetchStrategy() {
        testInitialDemand(
            withPrefetchStrategy: .byRequest,
            expectedSubscriptionHistory: [.requested(.unlimited)]
        )
    }

    func testBufferingInputDroppingNewest() throws {
        try testBufferingInput(whenFull: .dropNewest)
    }

    func testBufferingInputDroppingOldest() throws {
        try testBufferingInput(whenFull: .dropOldest)
    }

    func testBufferingInputFailingWhenBufferIsFull() throws {
        try testBufferingInput(whenFull: .customError { .oops })
    }

    func testReceiveValueAfterFinishing() throws {
        try testReceiveValueAfterCompleting(.finished)
    }

    func testReceiveValueAfterFailing() throws {
        try testReceiveValueAfterCompleting(.failure(.oops))
    }

    func testDeadlockWhenErroringOnFullBuffer() {
        var recursionCounter = 10
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .max(2),
            receiveValueDemand: .none,
            createSut: { publisher in
                publisher.buffer(
                    size: 0,
                    prefetch: .keepFull,
                    whenFull: .customError {
                        if recursionCounter == 0 { return TestingError.oops }
                        recursionCounter -= 1
                        _ = publisher.send(1000)
                        return TestingError.oops
                    }
                )
            }
        )

        assertCrashes {
            _ = helper.publisher.send(0)
        }
    }

    func testRecursionByRequestDropNewest() {
        testRecursion(prefetch: .byRequest, whenFull: .dropNewest)
    }

    func testRecursionByRequestDropOldest() {
        testRecursion(prefetch: .byRequest, whenFull: .dropOldest)
    }

    func testRecursionByRequestCustomError() {
        testRecursion(prefetch: .byRequest, whenFull: .customError { .oops })
    }

    func testRecursionKeepFullDropNewest() {
        testRecursion(prefetch: .keepFull, whenFull: .dropNewest)
    }

    func testRecursionKeepFullDropOldest() {
        testRecursion(prefetch: .keepFull, whenFull: .dropOldest)
    }

    func testRecursionKeepFullCustomError() {
        testRecursion(prefetch: .keepFull, whenFull: .customError { .oops })
    }

    func testRequestingUnlimitedDemandByRequestDropNewest() {
        testRequestingUnlimitedDemand(prefetch: .byRequest,
                                      whenFull: .dropNewest)
    }

    func testRequestingUnlimitedDemandByRequestDropOldest() {
        testRequestingUnlimitedDemand(prefetch: .byRequest,
                                      whenFull: .dropOldest)
    }

    func testRequestingUnlimitedDemandByRequestCustomError() {
        testRequestingUnlimitedDemand(prefetch: .byRequest,
                                      whenFull: .customError { .oops })
    }

    func testRequestingUnlimitedDemandKeepFullDropNewest() {
        testRequestingUnlimitedDemand(prefetch: .keepFull,
                                      whenFull: .dropNewest)
    }

    func testRequestingUnlimitedDemandKeepFullDropOldest() {
        testRequestingUnlimitedDemand(prefetch: .keepFull,
                                      whenFull: .dropOldest)
    }

    func testRequestingUnlimitedDemandKeepFullCustomError() {
        testRequestingUnlimitedDemand(prefetch: .keepFull,
                                      whenFull: .customError { .oops })
    }

    func testRequestingFiniteDemandByRequestDropNewest() {
        testRequestingFiniteDemand(prefetch: .byRequest, whenFull: .dropNewest)
    }

    func testRequestingFiniteDemandByRequestDropOldest() {
        testRequestingFiniteDemand(prefetch: .byRequest, whenFull: .dropOldest)
    }

    func testRequestingFiniteDemandByRequestCustomError() {
        testRequestingFiniteDemand(prefetch: .byRequest, whenFull: .customError { .oops })
    }

    func testRequestingFiniteDemandKeepFullDropNewest() {
        testRequestingFiniteDemand(prefetch: .keepFull, whenFull: .dropNewest)
    }

    func testRequestingFiniteDemandKeepFullDropOldest() {
        testRequestingFiniteDemand(prefetch: .keepFull, whenFull: .dropOldest)
    }

    func testRequestingFiniteDemandKeepFullCustomError() {
        testRequestingFiniteDemand(prefetch: .keepFull, whenFull: .customError { .oops })
    }

    func testBufferByRequestDropNewestReceiveSubscriptionTwice() throws {
        try testBufferReceiveSubscriptionTwice(prefetch: .byRequest,
                                               whenFull: .dropNewest)
    }

    func testBufferByRequestDropOldestReceiveSubscriptionTwice() throws {
        try testBufferReceiveSubscriptionTwice(prefetch: .byRequest,
                                               whenFull: .dropOldest)
    }

    func testBufferByRequestCustomErrorReceiveSubscriptionTwice() throws {
        try testBufferReceiveSubscriptionTwice(prefetch: .byRequest,
                                               whenFull: .customError { .oops })
    }

    func testBufferKeepFullDropNewestReceiveSubscriptionTwice() throws {
        try testBufferReceiveSubscriptionTwice(prefetch: .keepFull,
                                               whenFull: .dropNewest)
    }

    func testBufferKeepFullDropOldestReceiveSubscriptionTwice() throws {
        try testBufferReceiveSubscriptionTwice(prefetch: .keepFull,
                                               whenFull: .dropOldest)
    }

    func testBufferKeepFullCustomErrorReceiveSubscriptionTwice() throws {
        try testBufferReceiveSubscriptionTwice(prefetch: .keepFull,
                                               whenFull: .customError { .oops })
    }

    func testBufferByRequestDropNewestReceiveValueBeforeSubscription() {
        testBufferReceiveValueBeforeSubscription(prefetch: .byRequest,
                                                 whenFull: .dropNewest)
    }

    func testBufferByRequestDropOldestReceiveValueBeforeSubscription() {
        testBufferReceiveValueBeforeSubscription(prefetch: .byRequest,
                                                 whenFull: .dropOldest)
    }

    func testBufferByRequestCustomErrorReceiveValueBeforeSubscription() {
        testBufferReceiveValueBeforeSubscription(prefetch: .byRequest,
                                                 whenFull: .customError(unreachable))
    }

    func testBufferKeepFullDropNewestReceiveValueBeforeSubscription() {
        testBufferReceiveValueBeforeSubscription(prefetch: .keepFull,
                                                 whenFull: .dropNewest)
    }

    func testBufferKeepFullDropOldestReceiveValueBeforeSubscription() {
        testBufferReceiveValueBeforeSubscription(prefetch: .keepFull,
                                                 whenFull: .dropOldest)
    }

    func testBufferKeepFullCustomErrorReceiveValueBeforeSubscription() {
        testBufferReceiveValueBeforeSubscription(prefetch: .keepFull,
                                                 whenFull: .customError(unreachable))
    }

    func testBufferByRequestDropNewestReceiveCompletionBeforeSubscription() {
        testBufferReceiveCompletionBeforeSubscription(prefetch: .byRequest,
                                                      whenFull: .dropNewest)
    }

    func testBufferByRequestDropOldestReceiveCompletionBeforeSubscription() {
        testBufferReceiveCompletionBeforeSubscription(prefetch: .byRequest,
                                                      whenFull: .dropOldest)
    }

    func testBufferByRequestCustomErrorReceiveCompletionBeforeSubscription() {
        testBufferReceiveCompletionBeforeSubscription(prefetch: .byRequest,
                                                      whenFull: .customError(unreachable))
    }

    func testBufferKeepFullDropNewestReceiveCompletionBeforeSubscription() {
        testBufferReceiveCompletionBeforeSubscription(prefetch: .keepFull,
                                                      whenFull: .dropNewest)
    }

    func testBufferKeepFullDropOldestReceiveCompletionBeforeSubscription() {
        testBufferReceiveCompletionBeforeSubscription(prefetch: .keepFull,
                                                      whenFull: .dropOldest)
    }

    func testBufferKeepFullCustomErrorReceiveCompletionBeforeSubscription() {
        testBufferReceiveCompletionBeforeSubscription(prefetch: .keepFull,
                                                      whenFull: .customError(unreachable))
    }

    func testBufferByRequestDropNewestRequestBeforeSubscription() {
        testBufferRequestBeforeSubscription(prefetch: .byRequest,
                                            whenFull: .dropNewest)
    }

    func testBufferByRequestDropOldestRequestBeforeSubscription() {
        testBufferRequestBeforeSubscription(prefetch: .byRequest,
                                            whenFull: .dropOldest)
    }

    func testBufferByRequestCustomErrorRequestBeforeSubscription() {
        testBufferRequestBeforeSubscription(prefetch: .byRequest,
                                            whenFull: .customError(unreachable))
    }

    func testBufferKeepFullDropNewestRequestBeforeSubscription() {
        testBufferRequestBeforeSubscription(prefetch: .keepFull,
                                            whenFull: .dropNewest)
    }

    func testBufferKeepFullDropOldestRequestBeforeSubscription() {
        testBufferRequestBeforeSubscription(prefetch: .keepFull,
                                            whenFull: .dropOldest)
    }

    func testBufferKeepFullCustomErrorRequestBeforeSubscription() {
        testBufferRequestBeforeSubscription(prefetch: .keepFull,
                                            whenFull: .customError(unreachable))
    }

    func testBufferByRequestDropNewestCancelBeforeSubscription() {
        testBufferCancelBeforeSubscription(prefetch: .byRequest,
                                           whenFull: .dropNewest)
    }

    func testBufferByRequestDropOldestCancelBeforeSubscription() {
        testBufferCancelBeforeSubscription(prefetch: .byRequest,
                                           whenFull: .dropOldest)
    }

    func testBufferByRequestCustomErrorCancelBeforeSubscription() {
        testBufferCancelBeforeSubscription(prefetch: .byRequest,
                                           whenFull: .customError(unreachable))
    }

    func testBufferKeepFullDropNewestCancelBeforeSubscription() {
        testBufferCancelBeforeSubscription(prefetch: .keepFull,
                                           whenFull: .dropNewest)
    }

    func testBufferKeepFullDropOldestCancelBeforeSubscription() {
        testBufferCancelBeforeSubscription(prefetch: .keepFull,
                                           whenFull: .dropOldest)
    }

    func testBufferKeepFullCustomErrorCancelBeforeSubscription() {
        testBufferCancelBeforeSubscription(prefetch: .keepFull,
                                           whenFull: .customError(unreachable))
    }

    func testFailWhileSendingValues() throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.buffer(size: 5, prefetch: .byRequest, whenFull: .dropOldest) }
        )

        helper.tracking.onValue = { _ in
            helper.publisher.send(completion: .failure(.oops))
        }

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(5), .none)

        try XCTUnwrap(helper.downstreamSubscription).request(.max(3))

        XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                 .value(1),
                                                 .completion(.failure(.oops)),
                                                 .value(2),
                                                 .value(3)])
    }

    func testBufferByRequestDropNewestLifecycle() {
        testBufferLifecycle(prefetch: .byRequest,
                            whenFull: .dropNewest)
    }

    func testBufferByRequestDropOldestLifecycle() {
        testBufferLifecycle(prefetch: .byRequest,
                            whenFull: .dropOldest)
    }

    func testBufferByRequestCustomErrorLifecycle() {
        testBufferLifecycle(prefetch: .byRequest,
                            whenFull: .customError { TestingError.oops })
    }

    func testBufferKeepFullDropNewestLifecycle() {
        testBufferLifecycle(prefetch: .keepFull,
                            whenFull: .dropNewest)
    }

    func testBufferKeepFullDropOldestLifecycle() {
        testBufferLifecycle(prefetch: .keepFull,
                            whenFull: .dropOldest)
    }

    func testBufferKeepFullCustomErrorLifecycle() {
        testBufferLifecycle(prefetch: .keepFull,
                            whenFull: .customError { TestingError.oops })
    }

    func testBufferReflection() throws {
        try testReflection(
            parentInput: Int.self,
            parentFailure: TestingError.self,
            description: "Buffer",
            customMirror: expectedChildren(
                ("values", "[]"),
                ("state", .anything),
                ("downstreamDemand", "max(0)"),
                ("terminal", "nil")
            ),
            playgroundDescription: "Buffer",
            { $0.buffer(size: 13, prefetch: .keepFull, whenFull: .dropNewest) }
        )
    }

    // MARK: - Generic tests

    private func testInitialDemand(
        withPrefetchStrategy prefetch: Publishers.PrefetchStrategy,
        expectedSubscriptionHistory: [CustomSubscription.Event]
    ) {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: nil)
        let tracking = TrackingSubscriber()

        subscription.onRequest = { _ in
            XCTAssertEqual(tracking.history, [])
        }

        let buffer = publisher
            .buffer(size: 42, prefetch: prefetch, whenFull: .dropOldest)

        buffer.subscribe(tracking)

        XCTAssertEqual(tracking.history, [])

        publisher.send(subscription: subscription)

        XCTAssertEqual(subscription.history, expectedSubscriptionHistory)
        XCTAssertEqual(tracking.history, [.subscription("Buffer")])
    }

    private func testBufferingInput(
        whenFull: Publishers.BufferingStrategy<TestingError>
    ) throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.buffer(size: 3, prefetch: .byRequest, whenFull: whenFull) }
        )

        XCTAssertEqual(helper.tracking.history, [.subscription("Buffer")])
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)
        XCTAssertEqual(helper.publisher.send(3), .none)
        XCTAssertEqual(helper.publisher.send(4), .none)
        XCTAssertEqual(helper.publisher.send(5), .none)

        XCTAssertEqual(helper.tracking.history, [.subscription("Buffer")])
        switch whenFull {
        case .dropNewest, .dropOldest:
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .customError:
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }

        try XCTUnwrap(helper.downstreamSubscription).request(.max(3))

        switch whenFull {
        case .dropNewest:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(1),
                                                     .value(2),
                                                     .value(3)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .dropOldest:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(3),
                                                     .value(4),
                                                     .value(5)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .customError:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(1),
                                                     .value(2),
                                                     .value(3),
                                                     .completion(.failure(.oops))])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }

        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))

        switch whenFull {
        case .dropNewest:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(1),
                                                     .value(2),
                                                     .value(3)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .dropOldest:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(3),
                                                     .value(4),
                                                     .value(5)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .customError:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(1),
                                                     .value(2),
                                                     .value(3),
                                                     .completion(.failure(.oops))])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }
    }

    private func testRecursion(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<TestingError>
    ) {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: {
                $0.buffer(size: 5, prefetch: prefetch, whenFull: whenFull)
            }
        )

        helper.tracking.onValue = { _ in
            helper.downstreamSubscription?.request(.max(1))
            helper.downstreamSubscription?.request(.none)
        }

        helper.downstreamSubscription?.request(.max(3))

        for i in 0 ..< 10 {
            switch prefetch {
            case .byRequest:
                XCTAssertEqual(helper.publisher.send(i), .none)
            case .keepFull:
                XCTAssertEqual(helper.publisher.send(i), .max(1))
#if OPENCOMBINE_COMPATIBILITY_TEST
            @unknown default:
                unreachable()
#endif
            }
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                 .value(0),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4),
                                                 .value(5),
                                                 .value(6),
                                                 .value(7),
                                                 .value(8),
                                                 .value(9)])

        switch prefetch {
        case .byRequest:
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .keepFull:
            XCTAssertEqual(helper.subscription.history, [.requested(.max(5))])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }
    }

    private func testRequestingFiniteDemand(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<TestingError>
    ) {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: Subscribers.Demand.none,
            receiveValueDemand: .none,
            createSut: {
                $0.buffer(size: 5, prefetch: prefetch, whenFull: whenFull)
            }
        )

        for i in 0 ..< 10 {
            XCTAssertEqual(helper.publisher.send(i), .none)
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("Buffer")])

        switch (prefetch, whenFull) {
        case (.byRequest, .customError):
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
        case (.byRequest, _):
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case (.keepFull, .customError):
            XCTAssertEqual(helper.subscription.history, [.requested(.max(5)),
                                                         .cancelled])
        case (.keepFull, _):
            XCTAssertEqual(helper.subscription.history, [.requested(.max(5))])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }

        helper.downstreamSubscription?.request(.max(3))
        helper.downstreamSubscription?.request(.max(1))

        switch whenFull {
        case .dropNewest:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(0),
                                                     .value(1),
                                                     .value(2),
                                                     .value(3)])
        case .dropOldest:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(5),
                                                     .value(6),
                                                     .value(7),
                                                     .value(8)])
        case .customError:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(0),
                                                     .value(1),
                                                     .value(2),
                                                     .completion(.failure(.oops))])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }

        switch (prefetch, whenFull) {
        case (.byRequest, .customError):
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
        case (.byRequest, _):
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case (.keepFull, .customError):
            XCTAssertEqual(helper.subscription.history, [.requested(.max(5)),
                                                         .cancelled,
                                                         .requested(.max(3))])
        case (.keepFull, _):
            XCTAssertEqual(helper.subscription.history, [.requested(.max(5)),
                                                         .requested(.max(3)),
                                                         .requested(.max(1))])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }
    }

    private func testRequestingUnlimitedDemand(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<TestingError>
    ) {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: .unlimited,
            receiveValueDemand: .none,
            createSut: {
                $0.buffer(size: 5, prefetch: prefetch, whenFull: whenFull)
            }
        )

        for i in 0 ..< 10 {
            switch prefetch {
            case .byRequest:
                XCTAssertEqual(helper.publisher.send(i), .none)
            case .keepFull:
                XCTAssertEqual(helper.publisher.send(i), .max(1))
#if OPENCOMBINE_COMPATIBILITY_TEST
            @unknown default:
                unreachable()
#endif
            }
        }

        XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                 .value(0),
                                                 .value(1),
                                                 .value(2),
                                                 .value(3),
                                                 .value(4),
                                                 .value(5),
                                                 .value(6),
                                                 .value(7),
                                                 .value(8),
                                                 .value(9)])

        switch prefetch {
        case .byRequest:
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .keepFull:
            XCTAssertEqual(helper.subscription.history, [.requested(.max(5))])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }
    }

    private func testReceiveValueAfterCompleting(
        _ completion: Subscribers.Completion<TestingError>
    ) throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.buffer(size: 3, prefetch: .byRequest, whenFull: .dropOldest) }
        )

        helper.publisher.send(completion: completion)
        helper.publisher.send(completion: .finished) // Should be ignored
        helper.publisher.send(completion: .failure(.oops))

        switch completion {
        case .finished:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer")])
        case .failure:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .completion(.failure(.oops))])
        }
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(helper.publisher.send(1), .none)
        XCTAssertEqual(helper.publisher.send(2), .none)

        switch completion {
        case .finished:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer")])
        case .failure:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .completion(.failure(.oops))])
        }
        XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])

        try XCTUnwrap(helper.downstreamSubscription).request(.max(2))

        switch completion {
        case .finished:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(1),
                                                     .value(2)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .failure:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .completion(completion)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        }

        try XCTUnwrap(helper.downstreamSubscription).request(.max(1))

        switch completion {
        case .finished:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .value(1),
                                                     .value(2),
                                                     .completion(completion)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        case .failure:
            XCTAssertEqual(helper.tracking.history, [.subscription("Buffer"),
                                                     .completion(completion)])
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
        }
    }

    private func testBufferLifecycle(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<TestingError>
    ) {
        var deinitCounter = 0
        let onDeinit = { deinitCounter += 1 }

        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            publisher.onDeinit = onDeinit
            let buffer = publisher.buffer(size: 1, prefetch: prefetch, whenFull: whenFull)
            let tracking = TrackingSubscriber(
                receiveSubscription: { $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            buffer.subscribe(tracking)
            publisher.send(completion: .finished)
        }

        XCTAssertEqual(deinitCounter, 1)

        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            publisher.onDeinit = onDeinit
            let buffer = publisher.buffer(size: 1, prefetch: prefetch, whenFull: whenFull)
            let tracking = TrackingSubscriber(
                receiveSubscription: { $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            buffer.subscribe(tracking)
            publisher.send(completion: .failure(.oops))
        }

        XCTAssertEqual(deinitCounter, 2)

        var downstreamSubscription: Subscription?

        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            publisher.onDeinit = onDeinit
            let buffer = publisher.buffer(size: 1, prefetch: prefetch, whenFull: whenFull)
            let tracking = TrackingSubscriber(
                receiveSubscription: { downstreamSubscription = $0 },
                onDeinit: onDeinit
            )
            buffer.subscribe(tracking)
            publisher.send(completion: .failure(.oops))
        }

        XCTAssertEqual(deinitCounter, 3)
        downstreamSubscription?.cancel()
        XCTAssertEqual(deinitCounter, 3)

        do {
            let publisher = CustomPublisher(subscription: CustomSubscription())
            publisher.onDeinit = onDeinit
            let buffer = publisher.buffer(size: 1, prefetch: prefetch, whenFull: whenFull)
            let tracking = TrackingSubscriber(
                receiveSubscription: { $0.request(.unlimited) },
                onDeinit: onDeinit
            )
            buffer.subscribe(tracking)
        }

        XCTAssertEqual(deinitCounter, 4)
    }

    private func testBufferReceiveSubscriptionTwice(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<TestingError>
    ) throws {
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.buffer(size: 2, prefetch: prefetch, whenFull: whenFull) }
        )

        switch prefetch {
        case .keepFull:
            XCTAssertEqual(helper.subscription.history, [.requested(.max(2))])
        case .byRequest:
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited)])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        switch prefetch {
        case .keepFull:
            XCTAssertEqual(helper.subscription.history, [.requested(.max(2)),
                                                         .cancelled])
        case .byRequest:
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        switch prefetch {
        case .keepFull:
            XCTAssertEqual(helper.subscription.history, [.requested(.max(2)),
                                                         .cancelled,
                                                         .cancelled])
        case .byRequest:
            XCTAssertEqual(helper.subscription.history, [.requested(.unlimited),
                                                         .cancelled,
                                                         .cancelled])
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }
    }

    private func testBufferReceiveValueBeforeSubscription(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<Never>
    ) {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([], demand: .none),
            { $0.buffer(size: 2, prefetch: prefetch, whenFull: whenFull) }
        )
    }

    private func testBufferReceiveCompletionBeforeSubscription(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<Never>
    ) {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([]),
            { $0.buffer(size: 2, prefetch: prefetch, whenFull: whenFull) }
        )
    }

    private func testBufferRequestBeforeSubscription(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<Never>
    ) {
        testRequestBeforeSubscription(
            inputType: Int.self,
            shouldCrash: false,
            { $0.buffer(size: 2, prefetch: prefetch, whenFull: whenFull) }
        )
    }

    private func testBufferCancelBeforeSubscription(
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<Never>
    ) {
        switch prefetch {
        case .byRequest:
            testCancelBeforeSubscription(
                inputType: Int.self,
                expected: .history([.requested(.unlimited)]),
                { $0.buffer(size: 2, prefetch: prefetch, whenFull: whenFull) }
            )
        case .keepFull:
            testCancelBeforeSubscription(
                inputType: Int.self,
                expected: .history([.requested(.max(2))]),
                { $0.buffer(size: 2, prefetch: prefetch, whenFull: whenFull) }
            )
#if OPENCOMBINE_COMPATIBILITY_TEST
        @unknown default:
            unreachable()
#endif
        }
    }
}
