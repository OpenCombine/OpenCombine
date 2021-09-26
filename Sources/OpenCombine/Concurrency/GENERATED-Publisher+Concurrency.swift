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

#if canImport(_Concurrency)
import _Concurrency
#endif

// TODO: Uncomment when macOS 12 is released
#if canImport(_Concurrency) /* || compiler(>=5.5.x) */
extension Publisher where Failure == Never {

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public var values: AsyncPublisher<Self> {
        return .init(self)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct AsyncPublisher<Upstream: Publisher>: AsyncSequence
    where Upstream.Failure == Never
{

    public typealias Element = Upstream.Output

    public struct Iterator: AsyncIteratorProtocol {

        public typealias Element = Upstream.Output

        fileprivate let inner: Inner

        public func next() async -> Element? {
            return await withTaskCancellationHandler(
                handler: { [inner] in inner.cancel() },
                operation: { [inner] in await inner.next() }
            )
        }
    }

    public typealias AsyncIterator = Iterator

    private let publisher: Upstream

    public init(_ publisher: Upstream) {
        self.publisher = publisher
    }

    public func makeAsyncIterator() -> Iterator {
        let inner = Iterator.Inner()
        publisher.subscribe(inner)
        return Iterator(inner: inner)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension AsyncPublisher.Iterator {

    // TODO: Test if it's really cancellable
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

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public var values: AsyncThrowingPublisher<Self> {
        return .init(self)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct AsyncThrowingPublisher<Upstream: Publisher>: AsyncSequence
{

    public typealias Element = Upstream.Output

    public struct Iterator: AsyncIteratorProtocol {

        public typealias Element = Upstream.Output

        fileprivate let inner: Inner

        public func next() async throws -> Element? {
            return try await withTaskCancellationHandler(
                handler: { [inner] in inner.cancel() },
                operation: { [inner] in try await inner.next() }
            )
        }
    }

    public typealias AsyncIterator = Iterator

    private let publisher: Upstream

    public init(_ publisher: Upstream) {
        self.publisher = publisher
    }

    public func makeAsyncIterator() -> Iterator {
        let inner = Iterator.Inner()
        publisher.subscribe(inner)
        return Iterator(inner: inner)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension AsyncThrowingPublisher.Iterator {

    // TODO: Test if it's really cancellable
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
                    // TODO: Test that it's nil even if the publisher fails
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
                case .terminal:
                    lock.unlock()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
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
