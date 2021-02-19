//
//  Publishers.PrefixUntilOutput.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.11.2020.
//

extension Publisher {

    /// Republishes elements until another publisher emits an element.
    ///
    /// After the second publisher publishes an element, the publisher returned by this
    /// method finishes.
    ///
    /// - Parameter publisher: A second publisher.
    /// - Returns: A publisher that republishes elements until the second publisher
    ///   publishes an element.
    public func prefix<Other: Publisher>(
        untilOutputFrom publisher: Other
    ) -> Publishers.PrefixUntilOutput<Self, Other> {
        return .init(upstream: self, other: publisher)
    }
}

extension Publishers {
    public struct PrefixUntilOutput<Upstream: Publisher, Other: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// Another publisher, whose first output causes this publisher to finish.
        public let other: Other

        public init(upstream: Upstream, other: Other) {
            self.upstream = upstream
            self.other = other
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure, Downstream.Input == Output
        {
            upstream.subscribe(Inner(downstream: subscriber, trigger: other))
        }
    }
}

extension Publishers.PrefixUntilOutput {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private struct Termination: Subscriber {

            let inner: Inner

            var combineIdentifier: CombineIdentifier {
                return inner.combineIdentifier
            }

            func receive(subscription: Subscription) {
                inner.terminationReceive(subscription: subscription)
            }

            func receive(_ input: Other.Output) -> Subscribers.Demand {
                return inner.terminationReceive(input)
            }

            func receive(completion: Subscribers.Completion<Other.Failure>) {
                inner.terminationReceive(completion: completion)
            }
        }

        private var termination: Termination?
        private var prefixState = SubscriptionStatus.awaitingSubscription
        private var terminationState = SubscriptionStatus.awaitingSubscription
        private var triggered = false
        private let lock = UnfairLock.allocate()
        private let downstream: Downstream

        init(downstream: Downstream, trigger: Other) {
            self.downstream = downstream
            let termination = Termination(inner: self)
            self.termination = termination
            trigger.subscribe(termination)
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = prefixState else {
                lock.unlock()
                subscription.cancel()
                return
            }
            prefixState = triggered ? .terminal : .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = prefixState else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            let prefixState = self.prefixState
            let terminationSubscription = terminationState.subscription
            self.prefixState = .terminal
            terminationState = .terminal
            termination = nil
            lock.unlock()
            terminationSubscription?.cancel()
            if case .subscribed = prefixState {
                downstream.receive(completion: completion)
            }
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = prefixState else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            let prefixSubscription = prefixState.subscription
            let terminationSubscription = terminationState.subscription
            prefixState = .terminal
            terminationState = .terminal
            lock.unlock()
            prefixSubscription?.cancel()
            terminationSubscription?.cancel()
        }

        // MARK: - Private

        private func terminationReceive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = terminationState else {
                lock.unlock()
                subscription.cancel()
                return
            }
            terminationState = .subscribed(subscription)
            lock.unlock()
            subscription.request(.max(1))
        }

        private func terminationReceive(_ input: Other.Output) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = terminationState else {
                lock.unlock()
                return .none
            }
            let prefixSubscription = prefixState.subscription
            prefixState = .terminal
            terminationState = .terminal
            termination = nil
            triggered = true
            lock.unlock()
            prefixSubscription?.cancel()
            downstream.receive(completion: .finished)
            return .none
        }

        private func terminationReceive(
            completion: Subscribers.Completion<Other.Failure>
        ) {
            lock.lock()
            terminationState = .terminal
            termination = nil
            lock.unlock()
        }
    }
}
