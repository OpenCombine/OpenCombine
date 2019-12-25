//
//  Publishers.Catch.swift
//  
//
//  Created by Max Desiatov on 25/12/2019.
//

extension Publisher {
    /// Handles errors from an upstream publisher by replacing it with another publisher.
    ///
    /// The following example replaces any error from the upstream publisher and replaces the upstream with a `Just` publisher. This continues the stream by publishing a single value and completing normally.
    /// ```
    /// enum SimpleError: Error { case error }
    /// let errorPublisher = (0..<10).publisher.tryMap { v -> Int in
    ///     if v < 5 {
    ///         return v
    ///     } else {
    ///         throw SimpleError.error
    ///     }
    /// }
    ///
    /// let noErrorPublisher = errorPublisher.catch { _ in
    ///     return Just(100)
    /// }
    /// ```
    /// Backpressure note: This publisher passes through `request` and `cancel` to the upstream. After receiving an error, the publisher sends sends any unfulfilled demand to the new `Publisher`.
    /// - Parameter handler: A closure that accepts the upstream failure as input and returns a publisher to replace the upstream publisher.
    /// - Returns: A publisher that handles errors from an upstream publisher by replacing the failed publisher with another publisher.
    public func `catch`<P>(
        _ handler: @escaping (Self.Failure) -> P
    ) -> Publishers.Catch<Self, P> where P : Publisher, Self.Output == P.Output {
        return .init(upstream: self, handler: handler)
    }
}

extension Publishers {
    /// A publisher that handles errors from an upstream publisher by replacing the failed publisher with another publisher.
    public struct Catch<Upstream, NewPublisher> : Publisher where Upstream : Publisher, NewPublisher : Publisher, Upstream.Output == NewPublisher.Output {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = NewPublisher.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that accepts the upstream failure as input and returns a publisher to replace the upstream publisher.
        public let handler: (Upstream.Failure) -> NewPublisher

        /// Creates a publisher that handles errors from an upstream publisher by replacing the failed publisher with another publisher.
        ///
        /// - Parameters:
        ///   - upstream: The publisher that this publisher receives elements from.
        ///   - handler: A closure that accepts the upstream failure as input and returns a publisher to replace the upstream publisher.
        public init(upstream: Upstream, handler: @escaping (Upstream.Failure) -> NewPublisher) {
            self.upstream = upstream
            self.handler = handler
        }

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(
            subscriber: Downstream
        ) where Downstream: Subscriber, NewPublisher.Failure == Downstream.Failure, NewPublisher.Output == Downstream.Input {
            let inner = Publishers.Catch<Upstream, NewPublisher>.Inner<Downstream>(downstream: subscriber,
                              handler: handler)
            subscriber.receive(subscription: inner)
            upstream.subscribe(inner)
        }
    }
}


extension Publishers.Catch {

    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible
        where Downstream.Input == Output, Downstream.Failure == NewPublisher.Failure
    {
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard let subscription = subscription else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard let subscription = subscription else {
                lock.unlock()
                return
            }
            self.subscription = nil
            lock.unlock()

            subscription.cancel()
        }

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let handler: (Upstream.Failure) -> NewPublisher

        private let lock = UnfairLock.allocate()

        private var subscription: Subscription?

        let combineIdentifier = CombineIdentifier()

        init(downstream: Downstream, handler: @escaping (Upstream.Failure) -> NewPublisher) {
            self.downstream = downstream
            self.handler = handler
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            self.subscription = subscription
            lock.unlock()

            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case let .failure(error):
                let p = handler(error)
                p.subscribe(downstream)
            }
        }

        let description = "Catch"

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
    }
}
