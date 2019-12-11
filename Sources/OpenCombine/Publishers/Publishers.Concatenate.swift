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

    /// A publisher that emits all of one publisher’s elements before those from anothe
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
            prefix.subscribe(inner)
            subscriber.receive(subscription: inner)
        }
    }
}

extension Publishers.Concatenate: Equatable where Prefix: Equatable, Suffix: Equatable {}

extension Publishers.Concatenate {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Suffix.Output, Downstream.Failure == Suffix.Failure
    {
        typealias Input = Suffix.Output

        typealias Failure = Suffix.Failure

        private let downstream: Downstream

        private let suffix: Suffix

        private var prefixFinished = false

        private var demand = Subscribers.Demand.none

        private var upstream: Subscription?

        private var expectedSubscriptions = 2

        private let lock = UnfairLock.allocate()

        private let downstreamLock = UnfairRecursiveLock.allocate()

        fileprivate init(downstream: Downstream, suffix: Suffix) {
            self.downstream = downstream
            self.suffix = suffix
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard upstream == nil, expectedSubscriptions > 0 else {
                lock.unlock()
                subscription.cancel()
                return
            }
            upstream = subscription
            expectedSubscriptions -= 1
            let demand = self.demand
            lock.unlock()
            if demand > 0 {
                subscription.request(demand)
            }
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            demand -= 1
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            lock.lock()
            demand += newDemand
            lock.unlock()
            return newDemand
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            // Reading prefixFinished should be locked. Combine doesn't lock here.
            if prefixFinished {
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
                return
            }

            guard case .finished = completion else {
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
                return
            }

            prefixFinished = true // Should be locked as well?
            lock.lock()
            upstream = nil
            lock.unlock()
            suffix.subscribe(self)
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            self.demand += demand
            guard let subscription = upstream else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard let subscription = upstream else {
                lock.unlock()
                return
            }
            upstream = nil
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "Concatenate" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("upstreamSubscription", upstream as Any),
                ("suffix", suffix),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
