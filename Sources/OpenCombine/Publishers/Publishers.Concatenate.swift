//
//  Publishers.Concatenate.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.10.2019.
//

extension Publisher {

    /// Prefixes a `Publisher`'s output with the specified sequence.
    ///
    /// - Parameter elements: The elements to publish before this publisher’s elements.
    /// - Returns: A publisher that prefixes the specified elements prior to this
    ///   publisher’s elements.
    public func prepend(
        _ elements: Output...
    ) -> Publishers.Concatenate<Publishers.Sequence<[Output], Failure>, Self> {
        return prepend(elements)
    }

    /// Prefixes a `Publisher`'s output with the specified sequence.
    ///
    /// - Parameter elements: A sequence of elements to publish before this publisher’s
    ///   elements.
    /// - Returns: A publisher that prefixes the sequence of elements prior to this
    ///   publisher’s elements.
    public func prepend<Elements: Sequence>(
        _ elements: Elements
    ) -> Publishers.Concatenate<Publishers.Sequence<Elements, Failure>, Self>
        where Output == Elements.Element
    {
        return prepend(.init(sequence: elements))
    }

    /// Prefixes this publisher’s output with the elements emitted by the given publisher.
    ///
    /// The resulting publisher doesn’t emit any elements until the prefixing publisher
    /// finishes.
    ///
    /// - Parameter publisher: The prefixing publisher.
    /// - Returns: A publisher that prefixes the prefixing publisher’s elements prior to
    ///   this publisher’s elements.
    public func prepend<Prefix: Publisher>(
        _ publisher: Prefix
    ) -> Publishers.Concatenate<Prefix, Self>
        where Failure == Prefix.Failure, Output == Prefix.Output
    {
        return .init(prefix: publisher, suffix: self)
    }

    /// Append a `Publisher`'s output with the specified sequence.
    public func append(
        _ elements: Output...
    ) -> Publishers.Concatenate<Self, Publishers.Sequence<[Output], Failure>> {
        return append(elements)
    }

    /// Appends a `Publisher`'s output with the specified sequence.
    public func append<Elements: Sequence>(
        _ elements: Elements
    ) -> Publishers.Concatenate<Self, Publishers.Sequence<Elements, Failure>>
        where Output == Elements.Element
    {
        return append(.init(sequence: elements))
    }

    /// Appends this publisher’s output with the elements emitted by the given publisher.
    ///
    /// This operator produces no elements until this publisher finishes. It then produces
    /// this publisher’s elements, followed by the given publisher’s elements.
    /// If this publisher fails with an error, the prefixing publisher does not publish
    /// the provided publisher’s elements.
    ///
    /// - Parameter publisher: The appending publisher.
    /// - Returns: A publisher that appends the appending publisher’s elements after this
    ///   publisher’s elements.
    public func append<Suffix: Publisher>(
        _ publisher: Suffix
    ) -> Publishers.Concatenate<Self, Suffix>
        where Suffix.Failure == Failure, Suffix.Output == Output
    {
        return .init(prefix: self, suffix: publisher)
    }
}

extension Publishers {

    /// A publisher that emits all of one publisher’s elements before those from another
    /// publisher.
    public struct Concatenate<Prefix: Publisher, Suffix: Publisher>: Publisher
        where Prefix.Failure == Suffix.Failure, Prefix.Output == Suffix.Output
    {
        public typealias Output = Suffix.Output

        public typealias Failure = Suffix.Failure

        /// The publisher to republish, in its entirety, before republishing elements from
        /// `suffix`.
        public let prefix: Prefix

        /// The publisher to republish only after `prefix` finishes.
        public let suffix: Suffix

        public init(prefix: Prefix, suffix: Suffix) {
            self.prefix = prefix
            self.suffix = suffix
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Suffix.Failure == Downstream.Failure, Suffix.Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, suffix: suffix)
            prefix.subscribe(Inner<Downstream>.PrefixSubscriber(inner: inner))
        }
    }
}

extension Publishers.Concatenate: Equatable where Prefix: Equatable, Suffix: Equatable {}

extension Publishers.Concatenate {
    fileprivate final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Suffix.Output, Downstream.Failure == Suffix.Failure
    {
        typealias Input = Suffix.Output

        typealias Failure = Suffix.Failure

        fileprivate struct PrefixSubscriber {
            let inner: Inner<Downstream>
        }

        fileprivate struct SuffixSubscriber {
            let inner: Inner<Downstream>
        }

        private let downstream: Downstream

        private var prefixState = SubscriptionStatus.awaitingSubscription

        private var suffixState = SubscriptionStatus.awaitingSubscription

        private let suffix: Suffix

        private var pending = Subscribers.Demand.none

        private let lock = UnfairLock.allocate()

        fileprivate init(downstream: Downstream, suffix: Suffix) {
            self.downstream = downstream
            self.suffix = suffix
        }

        deinit {
            lock.deallocate()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            pending += demand
            guard let subscription = prefixState.subscription ?? suffixState.subscription
            else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            let upstreamSubscription =
                prefixState.subscription ?? suffixState.subscription
            prefixState = .terminal
            suffixState = .terminal
            lock.unlock()
            upstreamSubscription?.cancel()
        }

        var description: String { return "Concatenate" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }

        // MARK: - Private

        private func prefixReceive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = prefixState else {
                lock.unlock()
                subscription.cancel()
                return
            }
            prefixState = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        private func prefixReceive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = prefixState, pending != .none else {
                lock.unlock()
                return .none
            }
            pending -= 1
            lock.unlock()
            let newDemand = downstream.receive(input)
            if newDemand == .none {
                return .none
            }
            lock.lock()
            pending += newDemand
            lock.unlock()
            return newDemand
        }

        private func prefixReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = prefixState else {
                lock.unlock()
                return
            }
            prefixState = .terminal
            lock.unlock()
            switch completion {
            case .finished:
                suffix.subscribe(SuffixSubscriber(inner: self))
            case .failure:
                downstream.receive(completion: completion)
            }
        }

        private func suffixReceive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = suffixState else {
                lock.unlock()
                subscription.cancel()
                return
            }
            suffixState = .subscribed(subscription)
            let pending = self.pending
            lock.unlock()
            if pending != .none {
                subscription.request(pending)
            }
        }

        private func suffixReceive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = suffixState else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            return downstream.receive(input)
        }

        private func suffixReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = suffixState else {
                lock.unlock()
                return
            }
            prefixState = .terminal
            suffixState = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }
    }
}

// MARK: - PrefixSubscriber conformances

extension Publishers.Concatenate.Inner.PrefixSubscriber: Subscriber {

    fileprivate typealias Input = Suffix.Output

    fileprivate typealias Failure = Suffix.Failure

    fileprivate var combineIdentifier: CombineIdentifier {
        return inner.combineIdentifier
    }

    fileprivate func receive(subscription: Subscription) {
        inner.prefixReceive(subscription: subscription)
    }

    fileprivate func receive(_ input: Input) -> Subscribers.Demand {
        return inner.prefixReceive(input)
    }

    fileprivate func receive(completion: Subscribers.Completion<Failure>) {
        inner.prefixReceive(completion: completion)
    }
}

extension Publishers.Concatenate.Inner.PrefixSubscriber
    : CustomStringConvertible
{
    fileprivate var description: String {
        return inner.description
    }
}

extension Publishers.Concatenate.Inner.PrefixSubscriber
    : CustomReflectable
{
    fileprivate var customMirror: Mirror {
        return inner.customMirror
    }
}

extension Publishers.Concatenate.Inner.PrefixSubscriber
    : CustomPlaygroundDisplayConvertible
{
    fileprivate var playgroundDescription: Any {
        return inner.playgroundDescription
    }
}

// MARK: - SuffixSubscriber conformances

extension Publishers.Concatenate.Inner.SuffixSubscriber: Subscriber {

    fileprivate typealias Input = Suffix.Output

    fileprivate typealias Failure = Suffix.Failure

    fileprivate var combineIdentifier: CombineIdentifier {
        return inner.combineIdentifier
    }

    fileprivate func receive(subscription: Subscription) {
        inner.suffixReceive(subscription: subscription)
    }

    fileprivate func receive(_ input: Input) -> Subscribers.Demand {
        return inner.suffixReceive(input)
    }

    fileprivate func receive(completion: Subscribers.Completion<Failure>) {
        inner.suffixReceive(completion: completion)
    }
}

extension Publishers.Concatenate.Inner.SuffixSubscriber
    : CustomStringConvertible
{
    fileprivate var description: String {
        return inner.description
    }
}

extension Publishers.Concatenate.Inner.SuffixSubscriber
    : CustomReflectable
{
    fileprivate var customMirror: Mirror {
        return inner.customMirror
    }
}

extension Publishers.Concatenate.Inner.SuffixSubscriber
    : CustomPlaygroundDisplayConvertible
{
    fileprivate var playgroundDescription: Any {
        return inner.playgroundDescription
    }
}
