//
//  Publishers.ReplaceEmpty.swift
//  OpenCombine
//
//  Created by Joe Spadafora on 12/10/19.
//

#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

extension Publisher {

    /// Replaces an empty stream with the provided element.
    ///
    /// If the upstream publisher finishes without producing any elements,
    /// this publisher emits the provided element, then finishes normally.
    /// - Parameter output: An element to emit when the upstream publisher
    ///                     finishes without emitting any elements.
    /// - Returns: A publisher that replaces an empty stream with
    ///            the provided output element.
    public func replaceEmpty(with output: Output) -> Publishers.ReplaceEmpty<Self> {
        return .init(upstream: self, output: output)
    }
}

extension Publishers {

    /// A publisher that replaces an empty stream with a provided element.
    public struct ReplaceEmpty<Upstream>: Publisher where Upstream: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
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

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, output: output)
            upstream.subscribe(inner)
            subscriber.receive(subscription: inner)
        }
    }
}

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

        private var status = SubscriptionStatus.awaitingSubscription
        private var terminated = false
        private var pendingDemand = Subscribers.Demand.none
        private var lock = UnfairLock.allocate()
        private var isEmpty = true
        private var requestedDemand = false

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
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return .none
            }
            isEmpty = false
            pendingDemand -= 1
            lock.unlock()
            let demand = downstream.receive(input)
            guard demand > 0 else {
                return .none
            }
            lock.lock()
            pendingDemand += demand
            lock.unlock()
            return demand
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return
            }
            status = .terminal
            lock.unlock()
            switch completion {
            case .finished:
                if isEmpty {
                    _ = downstream.receive(output)
                }
                downstream.receive(completion: .finished)
            case .failure:
                downstream.receive(completion: completion)
            }
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            if terminated {
                status = .terminal
                lock.unlock()
                _ = downstream.receive(output)
                downstream.receive(completion: .finished)
                return
            }
            pendingDemand += demand
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            var shouldRequestUnlimited = false
            if !requestedDemand {
                requestedDemand = true
                shouldRequestUnlimited = true
            }
            lock.unlock()
            subscription.request(demand)
            if shouldRequestUnlimited {
                subscription.request(.unlimited)
            }
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
