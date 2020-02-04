//
//  Publishers.SwitchToLatest.swift
//  
//
//  Created by Sergej Jaskiewicz on 07.01.2020.
//

extension Publisher where Output: Publisher, Output.Failure == Failure {

    /// Flattens the stream of events from multiple upstream publishers to appear as if
    /// they were coming from a single stream of events.
    ///
    /// This operator switches the inner publisher as new ones arrive but keeps the outer
    /// one constant for downstream subscribers.
    /// For example, given the type `Publisher<Publisher<Data, NSError>, Never>`,
    /// calling `switchToLatest()` will result in the type `Publisher<Data, NSError>`.
    /// The downstream subscriber sees a continuous stream of values even though they may
    /// be coming from different upstream publishers.
    public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> {
        return .init(upstream: self)
    }
}

extension Publishers {

    /// A publisher that “flattens” nested publishers.
    ///
    /// Given a publisher that publishes Publishers, the `SwitchToLatest` publisher
    /// produces a sequence of events from only the most recent one.
    ///
    /// For example, given the type `Publisher<Publisher<Data, NSError>, Never>`,
    /// calling `switchToLatest()` will result in the type `Publisher<Data, NSError>`.
    /// The downstream subscriber sees a continuous stream of values even though they may
    /// be coming from different upstream publishers.
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
            upstream.subscribe(Outer(downstream: subscriber))
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

        private let _lock = UnfairLock.allocate()
        private let downstreamLock = UnfairRecursiveLock.allocate()
        private var _actualDownstream: Downstream?
        private var _upstreamSubscription: Subscription?
        private var _currentGenerationID: UInt64 = 0
        private var _latest: InnerLatest?
        private var _demand = Subscribers.Demand.none
        private var _outerDone = false
        private var _innerDone = false

        init(downstream: Downstream) {
            _actualDownstream = downstream
        }

        deinit {
            _lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            _lock.lock()
            guard _upstreamSubscription == nil, let downstream = _actualDownstream else {
                _lock.unlock()
                subscription.cancel()
                return
            }
            _upstreamSubscription = subscription
            _lock.unlock()
            downstreamLock.lock()
            downstream.receive(subscription: RoutingSubscription(parent: self))
            downstreamLock.unlock()
            subscription.request(.unlimited)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            _lock.lock()
            if _actualDownstream == nil {
                _lock.unlock()
                return .none
            }
            let previous = _latest
            _currentGenerationID += 1
            let innerLatest = InnerLatest(parent: self, identifier: _currentGenerationID)
            _latest = innerLatest
            _innerDone = false
            _lock.unlock()
            previous?.cancel()
            input.subscribe(innerLatest)
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            _lock.lock()
            guard let downstream = _actualDownstream,
                  let subscription = _upstreamSubscription else {
                _lock.unlock()
                return
            }
            let latest = _latest
            _latest = nil
            _actualDownstream = nil
            _upstreamSubscription = nil

            let error: Bool
            let bothDone: Bool
            switch completion {
            case .finished:
                error = false
                _outerDone = true
                bothDone = _innerDone
            case .failure:
                error = true
                bothDone = false
            }
            _lock.unlock()
            terminate(error: error,
                      bothDone: bothDone,
                      upstreamSubscription: subscription,
                      downstream: downstream,
                      latest: latest,
                      event: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            _lock.lock()
            if _actualDownstream == nil {
                _lock.unlock()
                return
            }
            let latest = _latest
            _demand += demand
            _lock.unlock()
            latest?.request(demand)
        }

        func cancel() {
            _lock.lock()
            if _actualDownstream == nil {
                _lock.unlock()
                return
            }
            let subscription = _upstreamSubscription
            let latest = _latest
            _actualDownstream = nil
            _upstreamSubscription = nil
            _lock.unlock()

            latest?.cancel()
            subscription?.cancel()
        }

        var description: String { return "SwitchToLatest" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }

        private func innerReceive(subscription: Subscription) {
            _lock.lock()
            let demand = _demand
            if demand > 0 {
                _lock.unlock()
                subscription.request(demand)
            } else {
                _lock.unlock()
            }
        }

        private func innerReceive(_ input: NestedPublisher.Output) -> Subscribers.Demand {
            _lock.lock()
            guard let downstream = _actualDownstream,
                  _latest!._identifier == _currentGenerationID else {
                _lock.unlock()
                return .none
            }

            // This will crash if we don't have any demand yet.
            // Combine crashes here too.
            _demand -= 1

            _lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            return newDemand
        }

        private func innerReceive(completion: Subscribers.Completion<Failure>) {
            _lock.lock()
            guard let downstream = _actualDownstream,
                  let subscription = _upstreamSubscription,
                  let latest = _latest,
                  latest._identifier == _currentGenerationID else {
                _lock.unlock()
                return
            }

            let error: Bool
            let bothDone: Bool
            switch completion {
            case .finished:
                error = false
                _innerDone = true
                bothDone = _outerDone
            case .failure:
                error = true
                bothDone = false
            }
            _lock.unlock()
            terminate(error: error,
                      bothDone: bothDone,
                      upstreamSubscription: subscription,
                      downstream: downstream,
                      latest: latest,
                      event: completion)
        }

        private func terminate(error: Bool,
                               bothDone: Bool,
                               upstreamSubscription: Subscription,
                               downstream: Downstream,
                               latest: InnerLatest?,
                               event: Subscribers.Completion<Failure>) {

            guard error || bothDone else {
                return
            }

            if error {
                upstreamSubscription.cancel()
                latest?.cancel()
            }

            downstreamLock.lock()
            downstream.receive(completion: event)
            downstreamLock.unlock()
        }
    }
}

extension Publishers.SwitchToLatest.Outer {
    private final class InnerLatest
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    {
        typealias Input = NestedPublisher.Output

        typealias Failure = NestedPublisher.Failure

        typealias Parent =
            Publishers.SwitchToLatest<NestedPublisher, Upstream>.Outer<Downstream>

        private let _lock = UnfairLock.allocate()
        private var _parent: Parent?
        fileprivate let _identifier: UInt64
        private var _innerSubscription: Subscription?

        init(parent: Parent, identifier: UInt64) {
            _parent = parent
            _identifier = identifier
        }

        deinit {
            _lock.deallocate()
        }

        func receive(subscription: Subscription) {
            _lock.lock()
            guard let parent = _parent else {
                _lock.unlock()
                return
            }
            if _innerSubscription == nil {
                _innerSubscription = subscription
                _lock.unlock()
                parent.innerReceive(subscription: subscription)
            } else {
                _lock.unlock()
                subscription.cancel()
            }
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            _lock.lock()
            guard let parent = _parent else {
                _lock.unlock()
                return .none
            }
            _lock.unlock()
            return parent.innerReceive(input)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            _lock.lock()
            guard let parent = _parent else {
                _lock.unlock()
                return
            }
            _parent = nil
            _innerSubscription = nil
            _lock.unlock()
            return parent.innerReceive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            _lock.lock()
            guard _parent != nil, let subscription = _innerSubscription else {
                _lock.unlock()
                return
            }
            _lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            _lock.lock()
            guard _parent != nil, let subscription = _innerSubscription else {
                _lock.unlock()
                return
            }
            _parent = nil
            _innerSubscription = nil
            _lock.unlock()
            subscription.cancel()
        }

        var description: String { return "SwitchToLatest" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.SwitchToLatest.Outer {
    private struct RoutingSubscription
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    {
        typealias Parent =
            Publishers.SwitchToLatest<NestedPublisher, Upstream>.Outer<Downstream>

        private let _parent: Parent

        init(parent: Parent) {
            _parent = parent
        }

        var combineIdentifier: CombineIdentifier {
            return _parent.combineIdentifier
        }

        func request(_ demand: Subscribers.Demand) {
            _parent.request(demand)
        }

        func cancel() {
            _parent.cancel()
        }

        var description: String { return "SwitchToLatest" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}
