//
//  Publishers.FlatMap.swift
//
//  Created by Eric Patey on 16.08.2019.
//

extension Publisher {
    /// Transforms all elements from an upstream publisher into a new or existing
    /// publisher.
    ///
    /// `flatMap` merges the output from all returned publishers into a single stream of
    /// output.
    ///
    /// - Parameters:
    ///   - maxPublishers: The maximum number of publishers produced by this method.
    ///   - transform: A closure that takes an element as a parameter and returns a
    ///     publisher that produces elements of that type.
    /// - Returns: A publisher that transforms elements from an upstream publisher into
    ///   a publisher of that element’s type.
    public func flatMap<Result, Child: Publisher>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (Output) -> Child
    ) -> Publishers.FlatMap<Child, Self>
        where Result == Child.Output, Failure == Child.Failure {
            return .init(upstream: self,
                         maxPublishers: maxPublishers,
                         transform: transform)
    }
}

extension Publishers {
    public struct FlatMap<Child: Publisher, Upstream: Publisher>: Publisher
        where Child.Failure == Upstream.Failure
    {
        public typealias Output = Child.Output

        public typealias Failure = Upstream.Failure

        public let upstream: Upstream

        public let maxPublishers: Subscribers.Demand

        public let transform: (Upstream.Output) -> Child

        public init(upstream: Upstream, maxPublishers: Subscribers.Demand,
                    transform: @escaping (Upstream.Output) -> Child) {
            self.upstream = upstream
            self.maxPublishers = maxPublishers
            self.transform = transform
        }
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Child.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
        {
            let inner = Inner(downstream: subscriber,
                              maxPublishers: maxPublishers,
                              map: transform)
            subscriber.receive(subscription: inner)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.FlatMap {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Child.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private typealias SubscriptionIndex = Int

        /// All requests to this subscription should be made with the `outerLock`
        /// acquired.
        private var outerSubscription: Subscription?

        // Must be recursive lock. Probably a bug in Combine.
        /// The lock for requesting from `outerSubscription`.
        private let outerLock = UnfairLock.allocate()

        /// The lock for modifying the state. All mutable state here should be
        /// read and modified with this lock acquired.
        /// The only exception is the `downstreamRecursive` field, which is guarded
        /// by the `downstreamLock`.
        private let lock = UnfairLock.allocate()

        /// All the calls to the downstream subscriber should be made with this lock
        /// acquired.
        private let downstreamLock = UnfairRecursiveLock.allocate()

        private let downstream: Downstream

        private var downstreamDemand = Subscribers.Demand.none

        /// This variable is set to `true` whenever we call `downstream.receive(_:)`,
        /// and then set back to `false`.
        private var downstreamRecursive = false

        private var innerRecursive = false
        private var subscriptions = [SubscriptionIndex : Subscription]()
        private var nextInnerIndex: SubscriptionIndex = 0
        private var pendingSubscriptions = 0
        private var buffer = [(SubscriptionIndex, Child.Output)]()
        private let maxPublishers: Subscribers.Demand
        private let map: (Input) -> Child
        private var cancelledOrCompleted = false
        private var outerFinished = false

        init(downstream: Downstream,
             maxPublishers: Subscribers.Demand,
             map: @escaping (Upstream.Output) -> Child) {
            self.downstream = downstream
            self.maxPublishers = maxPublishers
            self.map = map
        }

        deinit {
            outerLock.deallocate()
            lock.deallocate()
            downstreamLock.deallocate()
        }

        // MARK: - Subscriber

        fileprivate func receive(subscription: Subscription) {
            lock.lock()
            guard outerSubscription == nil, !cancelledOrCompleted else {
                lock.unlock()
                subscription.cancel()
                return
            }
            outerSubscription = subscription
            lock.unlock()
            subscription.request(maxPublishers)
        }

        fileprivate func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            let cancelledOrCompleted = self.cancelledOrCompleted
            lock.unlock()
            if cancelledOrCompleted {
                return .none
            }
            let child = map(input)
            lock.lock()
            let innerIndex = nextInnerIndex
            nextInnerIndex += 1
            pendingSubscriptions += 1
            lock.unlock()
            child.subscribe(Side(index: innerIndex, inner: self))
            return .none
        }

        fileprivate func receive(completion: Subscribers.Completion<Child.Failure>) {
            outerSubscription = nil
            lock.lock()
            outerFinished = true
            switch completion {
            case .finished:
                releaseLockThenSendCompletionDownstreamIfNeeded(outerFinished: true)
                return
            case .failure:
                let wasAlreadyCancelledOrCompleted = cancelledOrCompleted
                cancelledOrCompleted = true
                for (_, subscription) in subscriptions {
                    subscription.cancel()
                }
                subscriptions = [:]
                lock.unlock()
                if wasAlreadyCancelledOrCompleted {
                    return
                }
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            }
        }

        // MARK: - Subscription

        fileprivate func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            if downstreamRecursive {
                // downstreamRecursive being true means that downstreamLock
                // is already acquired.
                downstreamDemand += demand
                return
            }
            lock.lock()
            if cancelledOrCompleted {
                lock.unlock()
                return
            }
            if demand == .unlimited {
                downstreamDemand = .unlimited
                let buffer = self.buffer
                self.buffer = []
                let subscriptions = self.subscriptions
                lock.unlock()
                downstreamLock.lock()
                downstreamRecursive = true
                for (_, childOutput) in buffer {
                    _ = downstream.receive(childOutput)
                }
                downstreamRecursive = false
                downstreamLock.unlock()
                for (_, subscription) in subscriptions {
                    subscription.request(.unlimited)
                }
                lock.lock()
            } else {
                downstreamDemand += demand
                while !buffer.isEmpty && downstreamDemand > 0 {
                    // FIXME: This has quadratic complexity.
                    // This is what Combine does.
                    // Can we improve perfomance by using e. g. Deque instead of Array?
                    // Or array's cache locality makes this solution more efficient?
                    // Must benchmark before optimizing!
                    //
                    // https://www.cocoawithlove.com/blog/2016/09/22/deque.html
                    let (index, value) = buffer.removeFirst()
                    downstreamDemand -= 1
                    let subscription = subscriptions[index]
                    lock.unlock()
                    downstreamLock.lock()
                    downstreamRecursive = true
                    let additionalDemand = downstream.receive(value)
                    downstreamRecursive = false
                    downstreamLock.unlock()
                    if additionalDemand != .none {
                        lock.lock()
                        downstreamDemand += additionalDemand
                        lock.unlock()
                    }
                    if let subscription = subscription {
                        innerRecursive = true
                        subscription.request(.max(1))
                        innerRecursive = false
                    }
                    lock.lock()
                }
            }
            releaseLockThenSendCompletionDownstreamIfNeeded(outerFinished: outerFinished)
        }

        fileprivate func cancel() {
            lock.lock()
            cancelledOrCompleted = true
            let subscriptions = self.subscriptions
            self.subscriptions = [:]
            lock.unlock()
            for (_, subscription) in subscriptions {
                subscription.cancel()
            }
            // Combine doesn't acquire the lock here. Weird.
            outerSubscription?.cancel()
            outerSubscription = nil
        }

        // MARK: - Reflection

        fileprivate var description: String { return "FlatMap" }

        fileprivate var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        fileprivate var playgroundDescription: Any { return description }

        // MARK: - Private

        private func receiveInner(subscription: Subscription,
                                  _ index: SubscriptionIndex) {
            lock.lock()
            pendingSubscriptions -= 1
            subscriptions[index] = subscription

            let demand = downstreamDemand == .unlimited
                ? Subscribers.Demand.unlimited
                : .max(1)

            lock.unlock()
            subscription.request(demand)
        }

        private func receiveInner(_ input: Child.Output,
                                  _ index: SubscriptionIndex) -> Subscribers.Demand {
            lock.lock()
            if downstreamDemand == .unlimited {
                lock.unlock()
                downstreamLock.lock()
                downstreamRecursive = true
                _ = downstream.receive(input)
                downstreamRecursive = false
                downstreamLock.unlock()
                return .none
            }
            if downstreamDemand == .none || innerRecursive {
                buffer.append((index, input))
                lock.unlock()
                return .none
            }
            downstreamDemand -= 1
            lock.unlock()
            downstreamLock.lock()
            downstreamRecursive = true
            let newDemand = downstream.receive(input)
            downstreamRecursive = false
            downstreamLock.unlock()
            if newDemand > 0 {
                lock.lock()
                downstreamDemand += newDemand
                lock.unlock()
            }
            return .max(1)
        }

        private func receiveInner(completion: Subscribers.Completion<Child.Failure>,
                                  _ index: SubscriptionIndex) {
            switch completion {
            case .finished:
                lock.lock()
                subscriptions.removeValue(forKey: index)
                let downstreamCompleted = releaseLockThenSendCompletionDownstreamIfNeeded(
                    outerFinished: outerFinished
                )
                if !downstreamCompleted {
                    requestOneMorePublisher()
                }
            case .failure:
                lock.lock()
                if cancelledOrCompleted {
                    lock.unlock()
                    return
                }
                cancelledOrCompleted = true
                let subscriptions = self.subscriptions
                self.subscriptions = [:]
                lock.unlock()
                for (i, subscription) in subscriptions where i != index {
                    subscription.cancel()
                }
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            }
        }

        private func requestOneMorePublisher() {
            if maxPublishers != .unlimited {
                outerLock.lock()
                outerSubscription?.request(.max(1))
                outerLock.unlock()
            }
        }

        /// - Precondition: `lock` is acquired
        /// - Postcondition: `lock` is released
        ///
        /// - Returns: `true` if a completion was sent downstream
        @discardableResult
        private func releaseLockThenSendCompletionDownstreamIfNeeded(
            outerFinished: Bool
        ) -> Bool {
            #if DEBUG
            lock.assertOwner() // Sanity check
            #endif
            if !cancelledOrCompleted && outerFinished && buffer.isEmpty &&
                subscriptions.count + pendingSubscriptions == 0 {
                cancelledOrCompleted = true
                lock.unlock()
                downstreamLock.lock()
                downstream.receive(completion: .finished)
                downstreamLock.unlock()
                return true
            }

            lock.unlock()
            return false
        }

        // MARK: - Side

        private struct Side: Subscriber,
                             CustomStringConvertible,
                             CustomReflectable,
                             CustomPlaygroundDisplayConvertible {
            private let index: SubscriptionIndex
            private let inner: Inner
            fileprivate let combineIdentifier = CombineIdentifier()

            fileprivate init(index: SubscriptionIndex, inner: Inner) {
                self.index = index
                self.inner = inner
            }

            fileprivate func receive(subscription: Subscription) {
                inner.receiveInner(subscription: subscription, index)
            }

            fileprivate func receive(_ input: Child.Output) -> Subscribers.Demand {
                return inner.receiveInner(input, index)
            }

            fileprivate func receive(completion: Subscribers.Completion<Child.Failure>) {
                inner.receiveInner(completion: completion, index)
            }

            fileprivate var description: String { return "FlatMap" }

            fileprivate var customMirror: Mirror {
                let children = CollectionOfOne<Mirror.Child>(
                    ("parentSubscription", inner.combineIdentifier)
                )
                return Mirror(self, children: children)
            }

            fileprivate var playgroundDescription: Any { return description }
        }
    }
}
