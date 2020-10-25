// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃                                                                                     ┃
// ┃                   Auto-generated from GYB template. DO NOT EDIT!                    ┃
// ┃                                                                                     ┃
// ┃                                                                                     ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//
//  Publishers.Catch.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.12.2019.
//

extension Publisher {

    /// Handles errors from an upstream publisher by replacing it with another publisher.
    ///
    /// Use `catch()` to replace an error from an upstream publisher with a new publisher.
    ///
    /// In the example below, the `catch()` operator handles the `SimpleError` thrown by
    /// the upstream publisher by replacing the error with a `Just` publisher. This
    /// continues the stream by publishing a single value and completing normally.
    ///
    ///     struct SimpleError: Error {}
    ///     let numbers = [5, 4, 3, 2, 1, 0, 9, 8, 7, 6]
    ///     cancellable = numbers.publisher
    ///         .tryLast(where: {
    ///             guard $0 != 0 else { throw SimpleError() }
    ///             return true
    ///         })
    ///         .catch { error in
    ///             Just(-1)
    ///         }
    ///         .sink { print("\($0)") }
    ///         // Prints: -1
    ///
    /// Backpressure note: This publisher passes through `request` and `cancel` to
    /// the upstream. After receiving an error, the publisher sends sends any unfulfilled
    /// demand to the new `Publisher`.
    ///
    /// - SeeAlso: `replaceError`
    /// - Parameter handler: A closure that accepts the upstream failure as input and
    ///   returns a publisher to replace the upstream publisher.
    /// - Returns: A publisher that handles errors from an upstream publisher by replacing
    ///   the failed publisher with another publisher.
    public func `catch`<NewPublisher: Publisher>(
        _ handler: @escaping (Failure) -> NewPublisher
    ) -> Publishers.Catch<Self, NewPublisher>
        where NewPublisher.Output == Output
    {
        return .init(upstream: self, handler: handler)
    }

    /// Handles errors from an upstream publisher by either replacing it with another
    /// publisher or throwing a new error.
    ///
    /// Use `tryCatch(_:)` to decide how to handle from an upstream publisher by either
    /// replacing the publisher with a new publisher, or throwing a new error.
    ///
    /// In the example below, an array publisher emits values that a `tryMap(_:)` operator
    /// evaluates to ensure the values are greater than zero. If the values aren’t greater
    /// than zero, the operator throws an error to the downstream subscriber to let it
    /// know there was a problem. The subscriber, `tryCatch(_:)`, replaces the error with
    /// a new publisher using ``Just`` to publish a final value before the stream ends
    /// normally.
    ///
    ///     enum SimpleError: Error { case error }
    ///     var numbers = [5, 4, 3, 2, 1, -1, 7, 8, 9, 10]
    ///
    ///     cancellable = numbers.publisher
    ///         .tryMap { v in
    ///             if v > 0 {
    ///                 return v
    ///             } else {
    ///                 throw SimpleError.error
    ///             }
    ///         }
    ///         .tryCatch { error in
    ///             Just(0) // Send a final value before completing normally.
    ///                     // Alternatively, throw a new error to terminate the stream.
    ///     }
    ///       .sink(receiveCompletion: { print ("Completion: \($0).") },
    ///             receiveValue: { print ("Received \($0).") })
    ///     //    Received 5.
    ///     //    Received 4.
    ///     //    Received 3.
    ///     //    Received 2.
    ///     //    Received 1.
    ///     //    Received 0.
    ///     //    Completion: finished.
    ///
    /// - Parameter handler: A throwing closure that accepts the upstream failure as
    ///   input. This closure can either replace the upstream publisher with a new one,
    ///   or throw a new error to the downstream subscriber.
    /// - Returns: A publisher that handles errors from an upstream publisher by replacing
    ///   the failed publisher with another publisher, or an error.
    public func tryCatch<NewPublisher: Publisher>(
        _ handler: @escaping (Failure) throws -> NewPublisher
    ) -> Publishers.TryCatch<Self, NewPublisher>
        where NewPublisher.Output == Output
    {
        return .init(upstream: self, handler: handler)
    }
}

extension Publishers {

    /// A publisher that handles errors from an upstream publisher by replacing the failed
    /// publisher with another publisher.
    public struct Catch<Upstream: Publisher, NewPublisher: Publisher>: Publisher
        where Upstream.Output == NewPublisher.Output
    {
        public typealias Output = Upstream.Output

        public typealias Failure = NewPublisher.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that accepts the upstream failure as input and returns a publisher
        /// to replace the upstream publisher.
        public let handler: (Upstream.Failure) -> NewPublisher

        /// Creates a publisher that handles errors from an upstream publisher by
        /// replacing the failed publisher with another publisher.
        ///
        /// - Parameters:
        ///   - upstream: The publisher that this publisher receives elements from.
        ///   - handler: A closure that accepts the upstream failure as input and returns
        ///     a publisher to replace the upstream publisher.
        public init(upstream: Upstream,
                    handler: @escaping (Upstream.Failure) -> NewPublisher) {
            self.upstream = upstream
            self.handler = handler
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(downstream: subscriber, handler: handler)
            let uncaughtS = Inner.UncaughtS(inner: inner)
            upstream.subscribe(uncaughtS)
        }
    }

    /// A publisher that handles errors from an upstream publisher by replacing
    /// the failed publisher with another publisher or producing a new error.
    ///
    /// Because this publisher’s handler can throw an error, `Publishers.TryCatch` defines
    /// its `Failure` type as `Error`. This is different from `Publishers.Catch`, which
    /// gets its failure type from the replacement publisher.
    public struct TryCatch<Upstream: Publisher, NewPublisher: Publisher>: Publisher
        where Upstream.Output == NewPublisher.Output
    {
        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that accepts the upstream failure as input and either returns
        /// a publisher to replace the upstream publisher or throws an error.
        public let handler: (Upstream.Failure) throws -> NewPublisher

        /// Creates a publisher that handles errors from an upstream publisher by
        /// replacing the failed publisher with another publisher or by throwing an error.
        ///
        /// - Parameters:
        ///   - upstream: The publisher that this publisher receives elements from.
        ///   - handler: A closure that accepts the upstream failure as input and either
        ///     returns a publisher to replace the upstream publisher. If this closure
        ///     throws an error, the publisher terminates with the thrown error.
        public init(upstream: Upstream,
                    handler: @escaping (Upstream.Failure) throws -> NewPublisher) {
            self.upstream = upstream
            self.handler = handler
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(downstream: subscriber, handler: handler)
            let uncaughtS = Inner.UncaughtS(inner: inner)
            upstream.subscribe(uncaughtS)
        }
    }
}

extension Publishers.Catch {
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output,
              Downstream.Failure == NewPublisher.Failure
    {
        struct UncaughtS: Subscriber,
                          CustomStringConvertible,
                          CustomReflectable,
                          CustomPlaygroundDisplayConvertible
        {
            typealias Input = Upstream.Output

            typealias Failure = Upstream.Failure

            let inner: Inner

            var combineIdentifier: CombineIdentifier { return inner.combineIdentifier }

            func receive(subscription: Subscription) {
                inner.receivePre(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return inner.receivePre(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                return inner.receivePre(completion: completion)
            }

            var description: String { return inner.description }

            var customMirror: Mirror { return inner.customMirror }

            var playgroundDescription: Any { return description }
        }

        struct CaughtS: Subscriber,
                        CustomStringConvertible,
                        CustomReflectable,
                        CustomPlaygroundDisplayConvertible
        {
            typealias Input = NewPublisher.Output

            typealias Failure = NewPublisher.Failure

            let inner: Inner

            var combineIdentifier: CombineIdentifier { return inner.combineIdentifier }

            func receive(subscription: Subscription) {
                inner.receivePost(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return inner.receivePost(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                inner.receivePost(completion: completion)
            }

            var description: String { return inner.description }

            var customMirror: Mirror { return inner.customMirror }

            var playgroundDescription: Any { return description }
        }

        private enum State {
            case pendingPre
            case pre(Subscription)
            case pendingPost
            case post(Subscription)
            case cancelled
        }

        private let lock = UnfairLock.allocate()

        private var demand = Subscribers.Demand.none

        private var state = State.pendingPre

        private let downstream: Downstream

        private let handler: (Upstream.Failure) -> NewPublisher

        init(downstream: Downstream,
             handler: @escaping (Upstream.Failure) -> NewPublisher) {
            self.downstream = downstream
            self.handler = handler
        }

        deinit {
            lock.deallocate()
        }

        func receivePre(subscription: Subscription) {
            lock.lock()
            guard case .pendingPre = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .pre(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receivePre(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            demand -= 1
            lock.unlock()
            let newDemand = downstream.receive(input)
            lock.lock()
            demand += newDemand
            lock.unlock()
            return newDemand
        }

        func receivePre(completion: Subscribers.Completion<Upstream.Failure>) {
            switch completion {
            case .finished:
                lock.lock()
                switch state {
                case .pre:
                    state = .cancelled
                    lock.unlock()
                    downstream.receive(completion: .finished)
                case .pendingPre, .pendingPost, .post, .cancelled:
                    lock.unlock()
                }
            case .failure(let error):
                lock.lock()
                switch state {
                case .pre:
                    state = .pendingPost
                    lock.unlock()
                    handler(error).subscribe(CaughtS(inner: self))
                case .cancelled:
                    lock.unlock()
                case .pendingPre, .post, .pendingPost:
                    completionBeforeSubscription()
                }
            }
        }

        func receivePost(subscription: Subscription) {
            lock.lock()
            guard case .pendingPost = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .post(subscription)
            let demand = self.demand
            lock.unlock()
            if demand > 0 {
                subscription.request(demand)
            }
        }

        func receivePost(_ input: NewPublisher.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receivePost(completion: Subscribers.Completion<NewPublisher.Failure>) {
            lock.lock()
            guard case .post = state else {
                lock.unlock()
                return
            }
            state = .cancelled
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            switch state {
            case .pendingPre:
                // The client is only able to call the `request` method after we've sent
                // `self` downstream. We only do it in the `receivePre(subscription:)`
                // method, after setting `state` to `pre`.
                // After that `state` never becomes `pendingPre`.
                requestBeforeSubscription()
            case let .pre(subscription):
                self.demand += demand
                lock.unlock()
                subscription.request(demand)
            case .pendingPost:
                self.demand += demand
                lock.unlock()
            case let .post(subscription):
                lock.unlock()
                subscription.request(demand)
            case .cancelled:
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            switch state {
            case let .pre(subscription), let .post(subscription):
                state = .cancelled
                lock.unlock()
                subscription.cancel()
            case .pendingPre, .pendingPost, .cancelled:
                lock.unlock()
            }
        }

        var description: String { return "Catch" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryCatch {
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output,
              Downstream.Failure == Error
    {
        struct UncaughtS: Subscriber,
                          CustomStringConvertible,
                          CustomReflectable,
                          CustomPlaygroundDisplayConvertible
        {
            typealias Input = Upstream.Output

            typealias Failure = Upstream.Failure

            let inner: Inner

            var combineIdentifier: CombineIdentifier { return inner.combineIdentifier }

            func receive(subscription: Subscription) {
                inner.receivePre(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return inner.receivePre(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                return inner.receivePre(completion: completion)
            }

            var description: String { return inner.description }

            var customMirror: Mirror { return inner.customMirror }

            var playgroundDescription: Any { return description }
        }

        struct CaughtS: Subscriber,
                        CustomStringConvertible,
                        CustomReflectable,
                        CustomPlaygroundDisplayConvertible
        {
            typealias Input = NewPublisher.Output

            typealias Failure = NewPublisher.Failure

            let inner: Inner

            var combineIdentifier: CombineIdentifier { return inner.combineIdentifier }

            func receive(subscription: Subscription) {
                inner.receivePost(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return inner.receivePost(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                inner.receivePost(completion: completion)
            }

            var description: String { return inner.description }

            var customMirror: Mirror { return inner.customMirror }

            var playgroundDescription: Any { return description }
        }

        private enum State {
            case pendingPre
            case pre(Subscription)
            case pendingPost
            case post(Subscription)
            case cancelled
        }

        private let lock = UnfairLock.allocate()

        private var demand = Subscribers.Demand.none

        private var state = State.pendingPre

        private let downstream: Downstream

        private let handler: (Upstream.Failure) throws -> NewPublisher

        init(downstream: Downstream,
             handler: @escaping (Upstream.Failure) throws -> NewPublisher) {
            self.downstream = downstream
            self.handler = handler
        }

        deinit {
            lock.deallocate()
        }

        func receivePre(subscription: Subscription) {
            lock.lock()
            guard case .pendingPre = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .pre(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receivePre(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            demand -= 1
            lock.unlock()
            let newDemand = downstream.receive(input)
            lock.lock()
            demand += newDemand
            lock.unlock()
            return newDemand
        }

        func receivePre(completion: Subscribers.Completion<Upstream.Failure>) {
            switch completion {
            case .finished:
                lock.lock()
                switch state {
                case .pre:
                    state = .cancelled
                    lock.unlock()
                    downstream.receive(completion: .finished)
                case .pendingPre, .pendingPost, .post, .cancelled:
                    lock.unlock()
                }
            case .failure(let error):
                lock.lock()
                switch state {
                case .pre:
                    state = .pendingPost
                    lock.unlock()
                    do {
                        try handler(error).subscribe(CaughtS(inner: self))
                    } catch let anotherError {
                        lock.lock()
                        state = .cancelled
                        lock.unlock()
                        downstream.receive(completion: .failure(anotherError))
                    }
                case .cancelled:
                    lock.unlock()
                case .pendingPre, .post, .pendingPost:
                    completionBeforeSubscription()
                }
            }
        }

        func receivePost(subscription: Subscription) {
            lock.lock()
            guard case .pendingPost = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .post(subscription)
            let demand = self.demand
            lock.unlock()
            if demand > 0 {
                subscription.request(demand)
            }
        }

        func receivePost(_ input: NewPublisher.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receivePost(completion: Subscribers.Completion<NewPublisher.Failure>) {
            lock.lock()
            guard case .post = state else {
                lock.unlock()
                return
            }
            state = .cancelled
            lock.unlock()
            downstream.receive(completion: completion.eraseError())
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            switch state {
            case .pendingPre:
                // The client is only able to call the `request` method after we've sent
                // `self` downstream. We only do it in the `receivePre(subscription:)`
                // method, after setting `state` to `pre`.
                // After that `state` never becomes `pendingPre`.
                requestBeforeSubscription()
            case let .pre(subscription):
                self.demand += demand
                lock.unlock()
                subscription.request(demand)
            case .pendingPost:
                self.demand += demand
                lock.unlock()
            case let .post(subscription):
                lock.unlock()
                subscription.request(demand)
            case .cancelled:
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            switch state {
            case let .pre(subscription), let .post(subscription):
                state = .cancelled
                lock.unlock()
                subscription.cancel()
            case .pendingPre, .pendingPost, .cancelled:
                lock.unlock()
            }
        }

        var description: String { return "TryCatch" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}

private func completionBeforeSubscription(file: StaticString = #file,
                                          line: UInt = #line) -> Never {
    fatalError("Unexpected state: received completion but do not have subscription",
               file: file,
               line: line)
}

private func requestBeforeSubscription(file: StaticString = #file,
                                       line: UInt = #line) -> Never {
    fatalError("Unexpected state: request before subscription sent",
               file: file,
               line: line)
}
