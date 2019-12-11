//
//  Publishers.IgnoreOutput.swift
//
//  Created by Eric Patey on 16.08.2019.
//

extension Publisher {

    /// Ingores all upstream elements, but passes along a completion
    /// state (finished or failed).
    ///
    /// The output type of this publisher is `Never`.
    /// - Returns: A publisher that ignores all upstream elements.
    public func ignoreOutput() -> Publishers.IgnoreOutput<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {
    /// A publisher that ignores all upstream elements, but passes along a completion
    /// state (finish or failed).
    public struct IgnoreOutput<Upstream: Publisher>: Publisher {

        public typealias Output = Never

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Upstream.Failure, Downstream.Input == Never
        {
            upstream.subscribe(Inner<Downstream>(downstream: subscriber))
        }
    }
}

extension Publishers.IgnoreOutput {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Never, Downstream.Failure == Upstream.Failure
    {
        // NOTE: This class has been audited for thread safety

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private var status = SubscriptionStatus.awaitingSubscription

        private let lock = UnfairLock.allocate()

        fileprivate init(downstream: Downstream) {
            self.downstream = downstream
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

        func receive(_ input: Input) -> Subscribers.Demand {
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return
            }
            status = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            // ignore and requests from downstream since we'll never send
            // any values
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

        var description: String { return "IgnoreOutput" }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("status", status)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.IgnoreOutput: Equatable where Upstream: Equatable {}
