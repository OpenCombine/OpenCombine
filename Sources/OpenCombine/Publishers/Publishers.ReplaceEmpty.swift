//
//  Publishers.ReplaceEmpty.swift
//  OpenCombine
//
//  Created by Joe Spadafora on 12/10/19.
//

extension Publisher {

    /// Replaces an empty stream with the provided element.
    ///
    /// Use `replaceEmpty(with:)` to provide a replacement element if the upstream
    /// publisher finishes without producing any elements.
    ///
    /// In the example below, the empty `Double` array publisher doesn’t produce any
    /// elements, so `replaceEmpty(with:)` publishes `Double.nan` and finishes normally.
    ///
    ///     let numbers: [Double] = []
    ///     cancellable = numbers.publisher
    ///         .replaceEmpty(with: Double.nan)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints "(nan)".
    ///
    /// Conversely, providing a non-empty publisher publishes all elements and
    /// the publisher then terminates normally:
    ///
    ///     let otherNumbers: [Double] = [1.0, 2.0, 3.0]
    ///     cancellable2 = otherNumbers.publisher
    ///         .replaceEmpty(with: Double.nan)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: 1.0 2.0 3.0
    ///
    /// - Parameter output: An element to emit when the upstream publisher finishes
    ///   without emitting any elements.
    /// - Returns: A publisher that replaces an empty stream with the provided output
    ///   element.
    public func replaceEmpty(with output: Output) -> Publishers.ReplaceEmpty<Self> {
        return .init(upstream: self, output: output)
    }
}

extension Publishers {

    /// A publisher that replaces an empty stream with a provided element.
    public struct ReplaceEmpty<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The element to deliver when the upstream publisher finishes
        /// without delivering any elements.
        public let output: Upstream.Output

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream, output: Output) {
            self.upstream = upstream
            self.output = output
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, output: output)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.ReplaceEmpty: Equatable
    where Upstream: Equatable, Upstream.Output: Equatable {}

extension Publishers.ReplaceEmpty {

    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Failure == Downstream.Failure,
              Upstream.Output == Downstream.Input
    {

        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let output: Output
        private let downstream: Downstream

        private var receivedUpstream = false
        private var lock = UnfairLock.allocate()
        private var downstreamRequested = false
        private var finishedWithoutUpstream = false

        private var status = SubscriptionStatus.awaitingSubscription

        fileprivate init(downstream: Downstream, output: Output) {
            self.downstream = downstream
            self.output = output
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
            subscription.request(.unlimited)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return .none
            }
            receivedUpstream = true
            lock.unlock()
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return
            }
            status = .terminal
            if receivedUpstream {
                lock.unlock()
                downstream.receive(completion: completion)
                return
            }
            switch completion {
            case .finished:
                if downstreamRequested {
                    lock.unlock()
                    _ = downstream.receive(output)
                    downstream.receive(completion: completion)
                    return
                }
                finishedWithoutUpstream = true
                lock.unlock()
            case .failure:
                lock.unlock()
                downstream.receive(completion: completion)
            }
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            downstreamRequested = true
            if finishedWithoutUpstream {
                lock.unlock()
                _ = downstream.receive(output)
                downstream.receive(completion: .finished)
                return
            }
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "ReplaceEmpty" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}
