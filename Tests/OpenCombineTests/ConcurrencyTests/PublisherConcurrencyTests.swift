//
//  PublisherConcurrencyTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 12.12.2021.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

// swiftlint:disable:next line_length
#if !os(Windows) && !os(WASI) // TEST_DISCOVERY_CONDITION
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final class PublisherConcurrencyTests: XCTestCase {

    func testNonThrowingValuesFromSequence() async {

        let values = [1, 2, 3, 4, 5]

        let sequence = Publishers.Sequence<[Int], Never>(sequence: values)

        var actualValues = [Int]()

        for await value in sequence.values {
            actualValues.append(value)
        }

        XCTAssertEqual(actualValues, values)
    }

    func testThrowingValuesFromSequence() async throws {

        let values = [1, 2, 3, 4, 5]

        let sequence = Publishers.Sequence<[Int], TestingError>(sequence: values)

        var actualValues = [Int]()

        for try await value in sequence.values {
            actualValues.append(value)
        }

        XCTAssertEqual(actualValues, values)
    }

    func testRequestValuesBeforeSubscriptionNonThrowing() async throws {
        let publisher = CustomPublisherBase<Int, Never>(subscription: nil)

        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values

        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { _ = await asyncIterator.next() }
            group.addTask { _ = await asyncIterator.next() }
            group.addTask { _ = await asyncIterator.next() }
            group.addTask {

                // Make sure we send subscription _after_ the values are requested
                try await Task.sleep(nanoseconds: 10_000_000)
                publisher.send(subscription: subscription)

                XCTAssertEqual(publisher.send(1), .none)
                XCTAssertEqual(publisher.send(2), .none)
                XCTAssertEqual(publisher.send(3), .none)
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(subscription.history, [.requested(.max(3))])
    }

    func testRequestValuesBeforeSubscriptionThrowing() async throws {
        let publisher = CustomPublisher(subscription: nil)

        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values

        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { _ = try await asyncIterator.next() }
            group.addTask { _ = try await asyncIterator.next() }
            group.addTask { _ = try await asyncIterator.next() }
            group.addTask {

                // Make sure we send subscription _after_ the values are requested
                try await Task.sleep(nanoseconds: 10_000_000)
                publisher.send(subscription: subscription)

                XCTAssertEqual(publisher.send(1), .none)
                XCTAssertEqual(publisher.send(2), .none)
                XCTAssertEqual(publisher.send(3), .none)
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(subscription.history, [.requested(.max(3))])
    }

    func testReceiveSubscriptionTwiceNonThrowing() throws {
        let subscription1 = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription1)

        let asyncPublisher = publisher.values

        XCTAssertNil(publisher.erasedSubscriber)

        try withExtendedLifetime(asyncPublisher.makeAsyncIterator()) {

            let subscriber = try XCTUnwrap(publisher.subscriber)

            XCTAssertEqual(subscription1.history, [])

            let subscription2 = CustomSubscription()
            subscriber.receive(subscription: subscription2)
            XCTAssertEqual(subscription2.history, [.cancelled])

            subscriber.receive(subscription: subscription1)
            XCTAssertEqual(subscription1.history, [.cancelled])
        }
    }

    func testReceiveSubscriptionTwiceThrowing() throws {
        let subscription1 = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription1)

        let asyncPublisher = publisher.values

        XCTAssertNil(publisher.erasedSubscriber)

        try withExtendedLifetime(asyncPublisher.makeAsyncIterator()) {

            let subscriber = try XCTUnwrap(publisher.subscriber)

            XCTAssertEqual(subscription1.history, [])

            let subscription2 = CustomSubscription()
            subscriber.receive(subscription: subscription2)
            XCTAssertEqual(subscription2.history, [.cancelled])

            subscriber.receive(subscription: subscription1)
            XCTAssertEqual(subscription1.history, [.cancelled])
        }
    }

    func testNonThrowingInnerIsCancellable() throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)

        let asyncPublisher = publisher.values

        withExtendedLifetime(asyncPublisher.makeAsyncIterator()) {
            XCTAssertTrue(publisher.erasedSubscriber is Cancellable)
        }
    }

    func testThrowingInnerIsCancellable() throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let asyncPublisher = publisher.values

        withExtendedLifetime(asyncPublisher.makeAsyncIterator()) {
            XCTAssertTrue(publisher.erasedSubscriber is Cancellable)
        }
    }

    func testNonThrowingCancel() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task = Task { await asyncIterator.next() }

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await task.value
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Cancel `task` _after_ we request some values
                try await Task.sleep(nanoseconds: 10_000_000)
                task.cancel()
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 4)
        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .requested(.max(1)),
                                              .requested(.max(1)),
                                              .cancelled])
    }

    func testThrowingCancel() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task = Task { try await asyncIterator.next() }

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = try await task.value
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Cancel `task` _after_ we request some values
                try await Task.sleep(nanoseconds: 10_000_000)
                task.cancel()
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 4)
        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .requested(.max(1)),
                                              .requested(.max(1)),
                                              .cancelled])
    }

    func testNonThrowingCancelBeforeSubscription() async throws {
        let publisher = CustomPublisherBase<Int, Never>(subscription: nil)
        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task = Task { await asyncIterator.next() }

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await task.value
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Cancel `task` _after_ we request some values
                try await Task.sleep(nanoseconds: 10_000_000)
                task.cancel()
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 4)
        publisher.send(subscription: subscription)
        XCTAssertEqual(subscription.history, [.cancelled])
    }

    func testThrowingCancelBeforeSubscription() async throws {
        let publisher = CustomPublisher(subscription: nil)
        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task = Task { try await asyncIterator.next() }

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = try await task.value
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Cancel `task` _after_ we request some values
                try await Task.sleep(nanoseconds: 10_000_000)
                task.cancel()
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 4)
        publisher.send(subscription: subscription)
        XCTAssertEqual(subscription.history, [.cancelled])
    }

    func testNonThrowingCancelAfterCompletion() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task = Task { await asyncIterator.next() }

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await task.value
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Finish _after_ we request some values, then cancel `task`.
                try await Task.sleep(nanoseconds: 10_000_000)
                publisher.send(completion: .finished)
                task.cancel()
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 4)
        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .requested(.max(1)),
                                              .requested(.max(1))])
    }

    func testThrowingCancelAfterCompletion() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task = Task { try await asyncIterator.next() }

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = try await task.value
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Finish _after_ we request some values, then cancel `task`.
                try await Task.sleep(nanoseconds: 10_000_000)
                publisher.send(completion: .finished)
                task.cancel()
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 4)
        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .requested(.max(1)),
                                              .requested(.max(1))])
    }

    func testNonThrowingCancelAlreadyCancelled() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task = Task { await asyncIterator.next() }

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = await task.value
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Cancel `task` _after_ we request some values.
                try await Task.sleep(nanoseconds: 10_000_000)
                let inner = try XCTUnwrap(publisher.erasedSubscriber as? Cancellable)
                inner.cancel()
                inner.cancel()
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 2)
        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .cancelled])
    }

    func testThrowingCancelAlreadyCancelled() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task = Task { try await asyncIterator.next() }

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = try await task.value
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Cancel `task` _after_ we request some values.
                try await Task.sleep(nanoseconds: 10_000_000)
                let inner = try XCTUnwrap(publisher.erasedSubscriber as? Cancellable)
                inner.cancel()
                inner.cancel()
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 2)
        XCTAssertEqual(subscription.history, [.requested(.max(1)),
                                              .cancelled])
    }

    func testNonThrowingCrashesWhenReceivingUnwantedInput() {
        let publisher = CustomPublisherBase<Int, Never>(subscription: nil)
        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values

        withExtendedLifetime(asyncPublisher.makeAsyncIterator()) {

            // No subscription -> no crash
            XCTAssertEqual(publisher.send(42), .none)

            publisher.send(subscription: subscription)
            assertCrashes {
                _ = publisher.send(100)
            }
        }
    }

    func testThrowingCrashesWhenReceivingUnwantedInput() {
        let publisher = CustomPublisher(subscription: nil)
        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values

        withExtendedLifetime(asyncPublisher.makeAsyncIterator()) {

            // No subscription -> no crash
            XCTAssertEqual(publisher.send(42), .none)

            publisher.send(subscription: subscription)
            assertCrashes {
                _ = publisher.send(100)
            }
        }
    }

    func testNonThrowingReceiveInputBeforeSubscription() async throws {
        let publisher = CustomPublisherBase<Int, Never>(subscription: nil)
        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }

            group.addTask {
                // Send input _after_ we request some values.
                try await Task.sleep(nanoseconds: 10_000_000)
                XCTAssertEqual(publisher.send(42), .none)
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        publisher.send(subscription: subscription)
        XCTAssertEqual(subscription.history, [.requested(.max(2))])
    }

    func testThrowingReceiveInputBeforeSubscription() async throws {
        let publisher = CustomPublisher(subscription: nil)
        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }

            group.addTask {
                // Send input _after_ we request some values.
                try await Task.sleep(nanoseconds: 10_000_000)
                XCTAssertEqual(publisher.send(42), .none)
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        publisher.send(subscription: subscription)
        XCTAssertEqual(subscription.history, [.requested(.max(2))])
    }

    func testNonThrowingReceiveInputAfterCompletion() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }

            group.addTask {
                // Send completion and input _after_ we request some values.
                try await Task.sleep(nanoseconds: 10_000_000)
                publisher.send(completion: .finished)
                XCTAssertEqual(publisher.send(42), .none)
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .requested(.max(1))])
    }

    func testThrowingReceiveInputAfterCompletion() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }

            group.addTask {
                // Send completion and input _after_ we request some values.
                try await Task.sleep(nanoseconds: 10_000_000)
                publisher.send(completion: .finished)
                XCTAssertEqual(publisher.send(42), .none)
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .requested(.max(1))])
    }

    func testNonThrowingFinishesTwice() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, Never>(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                let value = await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }

            group.addTask {
                // Send completion and input _after_ we request some values.
                try await Task.sleep(nanoseconds: 10_000_000)
                publisher.send(completion: .finished)
                publisher.send(completion: .finished)
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .requested(.max(1))])
    }

    func testThrowingFinishBeforeSubscription() async throws {
        let publisher = CustomPublisher(subscription: nil)
        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000)
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }

            group.addTask {
                // Send completion _after_ we request some values.
                try await Task.sleep(nanoseconds: 20_000_000)
                publisher.send(completion: .finished)
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        publisher.send(subscription: subscription)
        XCTAssertEqual(subscription.history, [.cancelled])
    }

    func testThrowingFailBeforeSubscription() async throws {
        let publisher = CustomPublisher(subscription: nil)
        let subscription = CustomSubscription()

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                defer { numberOfTasksFinished += 1 }
                do {
                    let value = try await asyncIterator.next()
                    XCTFail("Didn't throw an error: \(String(describing: value))")
                } catch let error as TestingError {
                    XCTAssertEqual(error, .oops)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000)
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                // Send completion _after_ we request some values.
                try await Task.sleep(nanoseconds: 20_000_000)
                publisher.send(completion: .failure(.oops))
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        publisher.send(subscription: subscription)
        XCTAssertEqual(subscription.history, [.cancelled])
    }

    func testThrowingFinishAfterSubscription() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task1started = Atomic(false)
        let task2started = Atomic(false)
        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                task1started.set(true)
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                try await Task.sleepUntil { task1started.value }
                task2started.set(true)
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                try await Task.sleepUntil { task1started.value && task2started.value }
                publisher.send(completion: .finished)
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .requested(.max(1))])
    }

    func testThrowingFailAfterSubscription() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task1started = Atomic(false)
        let task2started = Atomic(false)
        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                defer { numberOfTasksFinished += 1 }
                task1started.set(true)
                do {
                    let value = try await asyncIterator.next()
                    XCTFail("Didn't throw an error: \(String(describing: value))")
                } catch let error as TestingError {
                    XCTAssertEqual(error, .oops)
                }
            }
            group.addTask {
                try await Task.sleepUntil { task1started.value }
                task2started.set(true)
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }

            group.addTask {
                // Send completion _after_ we request some values.
                try await Task.sleepUntil { task1started.value && task2started.value }
                publisher.send(completion: .failure(.oops))
                numberOfTasksFinished += 1
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .requested(.max(1))])
    }

    func testThrowingFailTwice() async throws {
        let subscription = CustomSubscription()
        let publisher = CustomPublisher(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let task1started = Atomic(false)
        let task2started = Atomic(false)
        let task3started = Atomic(false)
        let numberOfTasksFinished = Atomic<Int>(0)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                task1started.set(true)
                publisher.send(completion: .failure(.oops))
                numberOfTasksFinished += 1
            }
            group.addTask {
                defer { numberOfTasksFinished += 1 }
                try await Task.sleepUntil { task1started.value }
                task2started.set(true)
                do {
                    let value = try await asyncIterator.next()
                    XCTFail("Didn't throw an error: \(String(describing: value))")
                } catch let error as TestingError {
                    XCTAssertEqual(error, .oops)
                }
            }
            group.addTask {
                try await Task.sleepUntil { task1started.value && task2started.value }
                task3started.set(true)
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }
            group.addTask {
                try await Task.sleepUntil {
                    task1started.value && task2started.value && task3started.value
                }
                publisher.send(completion: .failure(.oops))
                numberOfTasksFinished += 1
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 4)
        XCTAssertEqual(subscription.history, [])
    }

    func testThrowingFailNonZeroDemand() async throws {
        // Make sure Inner doesn't save the error in its state if there is some demand.
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, RefError>(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        let numberOfTasksFinished = Atomic<Int>(0)

        var deinitCount = 0
        let onDeinit = { deinitCount += 1 }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                defer { numberOfTasksFinished += 1 }
                do {
                    let value = try await asyncIterator.next()
                    XCTFail("Didn't throw an error: \(String(describing: value))")
                } catch is RefError {
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000)
                let value = try await asyncIterator.next()
                XCTAssertNil(value)
                numberOfTasksFinished += 1
            }

            group.addTask {
                // Send completion _after_ we request some values.
                try await Task.sleep(nanoseconds: 20_000_000)
                publisher.send(completion: .failure(RefError(onDeinit: onDeinit)))
                numberOfTasksFinished += 1
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(numberOfTasksFinished, 3)
        // FIXME: This test case will sometimes fail on Xcode 15.0.1 / 14.3.1 / 14.2
        #if !canImport(Darwin)
        XCTAssertEqual(subscription.history, [.requested(.max(1)), .requested(.max(1))])
        #endif
        
        // FIXME: onDeinit will be called after this function and `defer { XCTAssertEqual(deinitCount, 1) }` is also not working
        #if swift(<5.8)
        XCTAssertEqual(deinitCount, 1)
        #endif

        withExtendedLifetime(publisher.erasedSubscriber) {}
    }

    func testThrowingFailWithZeroDemand() async throws {
        // Make sure Inner saves the error if there is no demand, and throws that error
        // when demand becomes non-zero
        let subscription = CustomSubscription()
        let publisher = CustomPublisherBase<Int, RefError>(subscription: subscription)

        let asyncPublisher = publisher.values
        let asyncIterator = IteratorWrapper(asyncPublisher.makeAsyncIterator())

        var deinitCount = 0
        let onDeinit = { deinitCount += 1 }

        publisher.send(completion: .failure(RefError(onDeinit: onDeinit)))

        do {
            let value = try await asyncIterator.next()
            XCTFail("Didn't throw an error: \(String(describing: value))")
        } catch is RefError {
        }

        XCTAssertEqual(subscription.history, [])
        #if swift(<5.8)
        // FIXME: onDeinit will be called after this function and `defer { XCTAssertEqual(deinitCount, 1) }` is also not working
        XCTAssertEqual(deinitCount, 1)
        #endif

        let value = try await asyncIterator.next()
        XCTAssertNil(value)

        withExtendedLifetime(publisher.erasedSubscriber) {}
    }
}

/// Adds reference semantics to the iterator to avoid the
/// "Mutation of captured var 'asyncIterator' in concurrently-executing code" error
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
private actor IteratorWrapper<Iterator: AsyncIteratorProtocol> {

    var iterator: Iterator

    init(_ iterator: Iterator) {
        self.iterator = iterator
    }

    func next() async rethrows -> Iterator.Element? {
        // Create a local copy to avoid the "Cannot call mutating async function 'next()'
        // on actor-isolated property 'iterator'" error
        var iteratorCopy = iterator
        let result = try await iteratorCopy.next()
        iterator = iteratorCopy
        return result
    }
}

private final class RefError: Error {

    private let onDeinit: () -> Void

    init(onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        onDeinit()
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Task where Success == Never, Failure == Never {
    static func sleepUntil(wakeupIntervalNanoseconds: UInt64 = 50_000_000,
                           _ condition: () -> Bool) async throws {
        while !condition() {
            try await sleep(nanoseconds: wakeupIntervalNanoseconds)
        }
        try await sleep(nanoseconds: wakeupIntervalNanoseconds)
    }
}

#endif
