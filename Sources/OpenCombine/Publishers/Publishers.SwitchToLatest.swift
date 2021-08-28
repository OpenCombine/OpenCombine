//
//  Publishers.SwitchToLatest.swift
//  
//
//  Created by Sergej Jaskiewicz on 07.01.2020.
//

extension Publisher where Output: Publisher, Output.Failure == Failure {

    /// Republishes elements sent by the most recently received publisher.
    ///
    /// This operator works with an upstream publisher of publishers, flattening
    /// the stream of elements to appear as if they were coming from a single stream of
    /// elements. It switches the inner publisher as new ones arrive but keeps the outer
    /// publisher constant for downstream subscribers.
    ///
    /// For example, given the type `AnyPublisher<URLSession.DataTaskPublisher, NSError>`,
    /// calling `switchToLatest()` results in the type
    /// `SwitchToLatest<(Data, URLResponse), URLError>`.
    /// The downstream subscriber sees a continuous stream of `(Data, URLResponse)`
    /// elements from what looks like a single `URLSession.DataTaskPublisher` even though
    /// the elements are coming from different upstream publishers.
    ///
    /// When this operator receives a new publisher from the upstream publisher, it
    /// cancels its previous subscription. Use this feature to prevent earlier publishers
    /// from performing unnecessary work, such as creating network request publishers from
    /// frequently updating user interface publishers.
    ///
    /// The following example updates a `PassthroughSubject` with a new value every
    /// `0.1` seconds. A `map(_:)` operator receives the new value and uses it to create
    /// a new `URLSession.DataTaskPublisher`. By using the `switchToLatest()` operator,
    /// the downstream sink subscriber receives the `(Data, URLResponse)` output type from
    /// the data task publishers, rather than the `URLSession.DataTaskPublisher` type
    /// produced by the `map(_:)` operator. Furthermore, creating each new data task
    /// publisher cancels the previous data task publisher.
    ///
    ///     let subject = PassthroughSubject<Int, Never>()
    ///     cancellable = subject
    ///         .setFailureType(to: URLError.self)
    ///         .map() { index -> URLSession.DataTaskPublisher in
    ///             let url = URL(string: "https://example.org/get?index=\(index)")!
    ///             return URLSession.shared.dataTaskPublisher(for: url)
    ///         }
    ///         .switchToLatest()
    ///         .sink(receiveCompletion: { print("Complete: \($0)") },
    ///               receiveValue: { (data, response) in
    ///                 guard let url = response.url else {
    ///                     print("Bad response.")
    ///                     return
    ///                 }
    ///                 print("URL: \(url)")
    ///         })
    ///
    ///     for index in 1...5 {
    ///         DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(index/10)) {
    ///             subject.send(index)
    ///         }
    ///     }
    ///
    ///     // Prints "URL: https://example.org/get?index=5"
    ///
    /// The exact behavior of this example depends on the value of `asyncAfter` and
    /// the speed of the network connection. If the delay value is longer, or the network
    /// connection is fast, the earlier data tasks may complete before `switchToLatest()`
    /// can cancel them. If this happens, the output includes multiple URLs whose tasks
    /// complete before cancellation.
    public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> {
        return .init(upstream: self)
    }
}

extension Publisher where Output: Publisher, Failure == Never {

    /// Republishes elements sent by the most recently received publisher.
    ///
    /// This operator works with an upstream publisher of publishers, flattening
    /// the stream of elements to appear as if they were coming from a single stream of
    /// elements. It switches the inner publisher as new ones arrive but keeps the outer
    /// publisher constant for downstream subscribers.
    ///
    /// When this operator receives a new publisher from the upstream publisher, it
    /// cancels its previous subscription. Use this feature to prevent earlier publishers
    /// from performing unnecessary work, such as creating network request publishers from
    /// frequently updating user interface publishers.
    public func switchToLatest() -> Publishers.SwitchToLatest<
        Output, Publishers.SetFailureType<Self, Output.Failure>
    > {
        return setFailureType(to: Output.Failure.self).switchToLatest()
    }
}

extension Publisher where Output: Publisher, Failure == Never, Output.Failure == Never {

    /// Republishes elements sent by the most recently received publisher.
    ///
    /// This operator works with an upstream publisher of publishers, flattening
    /// the stream of elements to appear as if they were coming from a single stream of
    /// elements. It switches the inner publisher as new ones arrive but keeps the outer
    /// publisher constant for downstream subscribers.
    ///
    /// When this operator receives a new publisher from the upstream publisher, it
    /// cancels its previous subscription. Use this feature to prevent earlier publishers
    /// from performing unnecessary work, such as creating network request publishers from
    /// frequently updating user interface publishers.
    public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> {
        return .init(upstream: self)
    }
}

extension Publisher where Output: Publisher, Output.Failure == Never {

    /// Republishes elements sent by the most recently received publisher.
    ///
    /// This operator works with an upstream publisher of publishers, flattening
    /// the stream of elements to appear as if they were coming from a single stream of
    /// elements. It switches the inner publisher as new ones arrive but keeps the outer
    /// publisher constant for downstream subscribers.
    ///
    /// When this operator receives a new publisher from the upstream publisher, it
    /// cancels its previous subscription. Use this feature to prevent earlier publishers
    /// from performing unnecessary work, such as creating network request publishers from
    /// frequently updating user interface publishers.
    public func switchToLatest() -> Publishers.SwitchToLatest<
        Publishers.SetFailureType<Output, Failure>,
        Publishers.Map<Self, Publishers.SetFailureType<Output, Failure>>
    > {
        return map { $0.setFailureType(to: Failure.self) }.switchToLatest()
    }
}

extension Publishers {

    /// A publisher that flattens nested publishers.
    ///
    /// Given a publisher that publishes `Publisher` instances,
    /// the `Publishers.SwitchToLatest` publisher produces a sequence of events from only
    /// the most recent one. For example, given the type
    /// `AnyPublisher<URLSession.DataTaskPublisher, NSError>`, calling `switchToLatest()`
    /// results in the type `SwitchToLatest<(Data, URLResponse), URLError>`.
    /// The downstream subscriber sees a continuous stream of `(Data, URLResponse)`
    /// elements from what looks like a single `URLSession.DataTaskPublisher` even though
    /// the elements are coming from different upstream publishers.
    ///
    /// When `Publishers.SwitchToLatest` receives a new publisher from the upstream
    /// publisher, it cancels its previous subscription. Use this feature to prevent
    /// earlier publishers from performing unnecessary work, such as creating network
    /// request publishers from frequently-updating user interface publishers.
    public struct SwitchToLatest<NestedPublisher: Publisher, Upstream: Publisher>
        : Publisher
        where Upstream.Output == NestedPublisher,
              Upstream.Failure == NestedPublisher.Failure
    {
        public typealias Output = NestedPublisher.Output

        public typealias Failure = NestedPublisher.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// Creates a publisher that “flattens” nested publishers.
        ///
        /// - Parameter upstream: The publisher from which this publisher receives
        ///   elements.
        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let outer = Outer(downstream: subscriber)
            subscriber.receive(subscription: outer)
            upstream.subscribe(outer)
        }
    }
}

extension Publishers.SwitchToLatest {
    fileprivate final class Outer<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == NestedPublisher.Output,
              Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream
        private var outerSubscription: Subscription?
        private var currentInnerSubscription: Subscription?
        private var currentInnerIndex: UInt64 = 0
        private var nextInnerIndex: UInt64 = 1
        private let lock = UnfairLock.allocate()
        private let downstreamLock = UnfairRecursiveLock.allocate()
        private var cancelled = false
        private var finished = false
        private var sentCompletion = false
        private var awaitingInnerSubscription = false
        private var downstreamDemand = Subscribers.Demand.none

        init(downstream: Downstream) {
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard outerSubscription == nil && !cancelled else {
                lock.unlock()
                subscription.cancel()
                return
            }
            outerSubscription = subscription
            lock.unlock()
            subscription.request(.unlimited)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            if cancelled || finished {
                lock.unlock()
                return .none
            }

            if let currentInnerSubscription = self.currentInnerSubscription.take()  {
                lock.unlock()
                currentInnerSubscription.cancel()
                lock.lock()
            }

            let index = nextInnerIndex
            currentInnerIndex = index
            nextInnerIndex += 1
            awaitingInnerSubscription = true
            lock.unlock()
            input.subscribe(Side(inner: self, index: index))
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            outerSubscription = nil
            finished = true

            if cancelled {
                lock.unlock()
                return
            }

            switch completion {
            case .finished:
                if awaitingInnerSubscription {
                    lock.unlock()
                    return
                }
                if currentInnerSubscription == nil {
                    sentCompletion = true
                    lock.unlock()
                    downstreamLock.lock()
                    downstream.receive(completion: completion)
                    downstreamLock.unlock()
                } else {
                    lock.unlock()
                }
            case .failure:
                let currentInnerSubscription = self.currentInnerSubscription.take()
                sentCompletion = true
                lock.unlock()
                currentInnerSubscription?.cancel()
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            }
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            downstreamDemand += demand
            if let currentInnerSubscription = self.currentInnerSubscription {
                lock.unlock()
                currentInnerSubscription.request(demand)
            } else {
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            cancelled = true
            let currentInnerSubscription = self.currentInnerSubscription.take()
            let outerSubscription = self.outerSubscription.take()
            lock.unlock()

            currentInnerSubscription?.cancel()
            outerSubscription?.cancel()
        }

        var description: String { return "SwitchToLatest" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }

        private func receiveInner(subscription: Subscription, _ index: UInt64) {
            lock.lock()
            guard currentInnerIndex == index &&
                  !cancelled &&
                  currentInnerSubscription == nil else {
                lock.unlock()
                subscription.cancel()
                return
            }

            currentInnerSubscription = subscription
            awaitingInnerSubscription = false
            let downstreamDemand = self.downstreamDemand
            lock.unlock()
            if downstreamDemand > 0 {
                subscription.request(downstreamDemand)
            }
        }

        private func receiveInner(_ input: NestedPublisher.Output,
                                  _ index: UInt64) -> Subscribers.Demand {
            lock.lock()
            guard currentInnerIndex == index && !cancelled else {
                lock.unlock()
                return .none
            }

            // This will crash if we don't have any demand yet.
            // Combine crashes here too.
            downstreamDemand -= 1

            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            if newDemand > 0 {
                lock.lock()
                downstreamDemand += newDemand
                lock.unlock()
            }

            return newDemand
        }

        private func receiveInner(completion: Subscribers.Completion<Failure>,
                                  _ index: UInt64) {
            lock.lock()
            guard currentInnerIndex == index && !cancelled else {
                lock.unlock()
                return
            }
            precondition(!awaitingInnerSubscription, "Unexpected completion")
            currentInnerSubscription = nil
            switch completion {
            case .finished:
                if sentCompletion || !finished {
                    lock.unlock()
                    return
                }
                sentCompletion = true
                lock.unlock()
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            case .failure:
                if sentCompletion {
                    lock.unlock()
                    return
                }
                cancelled = true
                let outerSubscription = self.outerSubscription.take()
                sentCompletion = true
                lock.unlock()
                outerSubscription?.cancel()
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            }
        }
    }
}

extension Publishers.SwitchToLatest.Outer {
    private struct Side
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    {
        typealias Input = NestedPublisher.Output

        typealias Failure = NestedPublisher.Failure

        typealias Outer =
            Publishers.SwitchToLatest<NestedPublisher, Upstream>.Outer<Downstream>

        private let index: UInt64
        private let outer: Outer

        let combineIdentifier = CombineIdentifier()

        init(inner: Outer, index: UInt64) {
            self.index = index
            self.outer = inner
        }

        func receive(subscription: Subscription) {
            outer.receiveInner(subscription: subscription, index)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return outer.receiveInner(input, index)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            outer.receiveInner(completion: completion, index)
        }

        var description: String { return "SwitchToLatest" }

        var customMirror: Mirror {
            let children = CollectionOfOne<Mirror.Child>(
                ("parentSubscription", outer.combineIdentifier)
            )
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
