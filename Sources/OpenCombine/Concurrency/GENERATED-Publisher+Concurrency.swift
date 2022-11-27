// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃                                                                                     ┃
// ┃                   Auto-generated from GYB template. DO NOT EDIT!                    ┃
// ┃                                                                                     ┃
// ┃                                                                                     ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//
//  Publisher+Concurrency.swift
// 
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

#if canImport(_Concurrency) && compiler(>=5.5)
import _Concurrency
#endif

#if canImport(_Concurrency) && compiler(>=5.5) || compiler(>=5.5.1)
extension Publisher where Failure == Never {

    /// The elements produced by the publisher, as an asynchronous sequence.
    ///
    /// This property provides an `AsyncPublisher`, which allows you to use
    /// the Swift `async`-`await` syntax to receive the publisher's elements.
    /// Because `AsyncPublisher` conforms to `AsyncSequence`, you iterate over its
    /// elements with a `for`-`await`-`in` loop, rather than attaching a subscriber.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var values: AsyncPublisher<Self> {
        return .init(self)
    }
}

/// A publisher that exposes its elements as an asynchronous sequence.
///
/// `AsyncPublisher` conforms to `AsyncSequence`, which allows callers to receive
/// values with the `for`-`await`-`in` syntax, rather than attaching a `Subscriber`.
///
/// Use the `values` property of the `Publisher` protocol to wrap an existing publisher
/// with an instance of this type.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct AsyncPublisher<Upstream: Publisher>: AsyncSequence
    where Upstream.Failure == Never
{

    public typealias Element = Upstream.Output

    /// The iterator that produces elements of the asynchronous publisher sequence.
    public struct Iterator: AsyncIteratorProtocol {

        public typealias Element = Upstream.Output

        fileprivate let inner: Inner

        /// Produces the next element in the prefix sequence.
        ///
        /// - Returns: The next published element, or `nil` if the publisher finishes
        ///   normally.
        public mutating func next() async -> Element? {
            return await withTaskCancellationHandler(
                operation: { [inner] in await inner.next() },
                onCancel: { [inner] in inner.cancel() }
            )
        }
    }

    /// The type of asynchronous iterator that produces elements of this
    /// asynchronous sequence.
    public typealias AsyncIterator = Iterator

    private let publisher: Upstream

    /// Creates a publisher that exposes elements received from an upstream publisher as
    /// a throwing asynchronous sequence.
    ///
    /// - Parameter publisher: An upstream publisher. The asynchronous publisher converts
    ///   elements received from this publisher into an asynchronous sequence.
    public init(_ publisher: Upstream) {
        self.publisher = publisher
    }

    /// Creates the asynchronous iterator that produces elements of this asynchronous
    /// sequence.
    ///
    /// - Returns: An instance of the `AsyncIterator` type used to produce elements of
    ///   the asynchronous sequence.
    public func makeAsyncIterator() -> Iterator {
        let inner = Iterator.Inner()
        publisher.subscribe(inner)
        return Iterator(inner: inner)
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension AsyncPublisher.Iterator {

    fileprivate final class Inner: Subscriber, Cancellable {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private enum State {
            case awaitingSubscription
            case subscribed(Subscription)
            case terminal
        }

        private let lock = UnfairLock.allocate()
        private var pending: [UnsafeContinuation<Input?, Never>] = []
        private var state = State.awaitingSubscription
        private var pendingDemand = Subscribers.Demand.none

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            let pendingDemand = self.pendingDemand
            self.pendingDemand = .none
            lock.unlock()
            if pendingDemand != .none {
                subscription.request(pendingDemand)
            }
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                let pending = self.pending.take()
                lock.unlock()
                pending.resumeAllWithNil()
                return .none
            }
            precondition(!pending.isEmpty, "Received an output without requesting demand")
            let continuation = pending.removeFirst()
            lock.unlock()
            continuation.resume(returning: input)
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            state = .terminal
            let pending = self.pending.take()
            lock.unlock()
            pending.resumeAllWithNil()
        }

        func cancel() {
            lock.lock()
            let pending = self.pending.take()
            guard case .subscribed(let subscription) = state else {
                state = .terminal
                lock.unlock()
                pending.resumeAllWithNil()
                return
            }
            state = .terminal
            lock.unlock()
            subscription.cancel()
            pending.resumeAllWithNil()
        }

        fileprivate func next() async -> Input? {
            return await withUnsafeContinuation { continuation in
                lock.lock()
                switch state {
                case .awaitingSubscription:
                    pending.append(continuation)
                    pendingDemand += 1
                    lock.unlock()
                case .subscribed(let subscription):
                    pending.append(continuation)
                    lock.unlock()
                    subscription.request(.max(1))
                case .terminal:
                    lock.unlock()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
extension Publisher {

    /// The elements produced by the publisher, as a throwing asynchronous sequence.
    ///
    /// This property provides an `AsyncThrowingPublisher`, which allows you to use
    /// the Swift `async`-`await` syntax to receive the publisher's elements.
    /// Because `AsyncPublisher` conforms to `AsyncSequence`, you iterate over its
    /// elements with a `for`-`await`-`in` loop, rather than attaching a subscriber.
    /// If the publisher terminates with an error, the awaiting caller receives the error
    /// as a `throw`.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var values: AsyncThrowingPublisher<Self> {
        return .init(self)
    }
}

/// A publisher that exposes its elements as a throwing asynchronous sequence.
///
/// `AsyncThrowingPublisher` conforms to `AsyncSequence`, which allows callers to receive
/// values with the `for`-`await`-`in` syntax, rather than attaching a `Subscriber`.
/// If the upstream publisher terminates with an error, `AsyncThrowingPublisher` throws
/// the error to the awaiting caller.
///
/// Use the `values` property of the `Publisher` protocol to wrap an existing publisher
/// with an instance of this type.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct AsyncThrowingPublisher<Upstream: Publisher>: AsyncSequence
{

    public typealias Element = Upstream.Output

    /// The iterator that produces elements of the asynchronous publisher sequence.
    public struct Iterator: AsyncIteratorProtocol {

        public typealias Element = Upstream.Output

        fileprivate let inner: Inner

        /// Produces the next element in the prefix sequence.
        ///
        /// - Returns: The next published element, or `nil` if the publisher finishes
        ///   normally.
        ///   If the publisher terminates with an error, the call point receives
        ///   the error as a `throw`.
        public mutating func next() async throws -> Element? {
            return try await withTaskCancellationHandler(
                operation: { [inner] in try await inner.next() },
                onCancel: { [inner] in inner.cancel() }
            )
        }
    }

    /// The type of asynchronous iterator that produces elements of this
    /// asynchronous sequence.
    public typealias AsyncIterator = Iterator

    private let publisher: Upstream

    /// Creates a publisher that exposes elements received from an upstream publisher as
    /// an asynchronous sequence.
    ///
    /// - Parameter publisher: An upstream publisher. The asynchronous publisher converts
    ///   elements received from this publisher into an asynchronous sequence.
    public init(_ publisher: Upstream) {
        self.publisher = publisher
    }

    /// Creates the asynchronous iterator that produces elements of this asynchronous
    /// sequence.
    ///
    /// - Returns: An instance of the `AsyncIterator` type used to produce elements of
    ///   the asynchronous sequence.
    public func makeAsyncIterator() -> Iterator {
        let inner = Iterator.Inner()
        publisher.subscribe(inner)
        return Iterator(inner: inner)
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension AsyncThrowingPublisher.Iterator {

    fileprivate final class Inner: Subscriber, Cancellable {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private enum State {
            case awaitingSubscription
            case subscribed(Subscription)
            case terminal(Error?)
        }

        private let lock = UnfairLock.allocate()
        private var pending: [UnsafeContinuation<Input?, Error>] = []
        private var state = State.awaitingSubscription
        private var pendingDemand = Subscribers.Demand.none

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            let pendingDemand = self.pendingDemand
            self.pendingDemand = .none
            lock.unlock()
            if pendingDemand != .none {
                subscription.request(pendingDemand)
            }
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                let pending = self.pending.take()
                lock.unlock()
                pending.resumeAllWithNil()
                return .none
            }
            precondition(!pending.isEmpty, "Received an output without requesting demand")
            let continuation = pending.removeFirst()
            lock.unlock()
            continuation.resume(returning: input)
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            switch state {
            case .awaitingSubscription, .subscribed:
                if let continuation = pending.first {
                    state = .terminal(nil)
                    let remaining = pending.take().dropFirst()
                    lock.unlock()
                    switch completion {
                    case .finished:
                        continuation.resume(returning: nil)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    remaining.resumeAllWithNil()
                } else {
                    state = .terminal(completion.failure)
                    lock.unlock()
                }
            case .terminal:
                let pending = self.pending.take()
                lock.unlock()
                pending.resumeAllWithNil()
            }
        }

        func cancel() {
            lock.lock()
            let pending = self.pending.take()
            guard case .subscribed(let subscription) = state else {
                state = .terminal(nil)
                lock.unlock()
                pending.resumeAllWithNil()
                return
            }
            state = .terminal(nil)
            lock.unlock()
            subscription.cancel()
            pending.resumeAllWithNil()
        }

        fileprivate func next() async throws -> Input? {
            return try await withUnsafeThrowingContinuation { continuation in
                lock.lock()
                switch state {
                case .awaitingSubscription:
                    pending.append(continuation)
                    pendingDemand += 1
                    lock.unlock()
                case .subscribed(let subscription):
                    pending.append(continuation)
                    lock.unlock()
                    subscription.request(.max(1))
                case .terminal(nil):
                    lock.unlock()
                    continuation.resume(returning: nil)
                case .terminal(let error?):
                    state = .terminal(nil)
                    lock.unlock()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Sequence {
    fileprivate func resumeAllWithNil<Output, Failure: Error>()
        where Element == UnsafeContinuation<Output?, Failure>
    {
        for continuation in self {
            continuation.resume(returning: nil)
        }
    }
}
#endif
