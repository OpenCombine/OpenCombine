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
            return Publishers.FlatMap(upstream: self,
                                      maxPublishers: maxPublishers,
                                      transform: transform)
    }
}

extension Publishers {

    public struct FlatMap<Child: Publisher, Upstream: Publisher>: Publisher
        where Child.Failure == Upstream.Failure
    {
        /// The kind of values published by this publisher.
        public typealias Output = Child.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
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

        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Child.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
        {
            let inner = Inner(downstream: subscriber,
                              maxPublishers: maxPublishers,
                              transform: transform)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.FlatMap {

    fileprivate final class Inner<Downstream: Subscriber>
        : CustomStringConvertible,
          Cancellable
        where Downstream.Input == Child.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private typealias PendingValue = (
            value: Downstream.Input,
            // If the value was buffered at the time it became available, and the child's
            // demand was left at `.none` we keep track of the child in `pausedChild` so
            // that we can demand some more of it after sending this value.
            pausedChild: ChildSubscriber?
        )

        private let lock = Lock(recursive: false)
        private let maxPublishers: Subscribers.Demand
        private let transform: (Input) -> Child

        // Locking rules for this class.
        //  - All mutable state must only be accessed while `lock` is held.
        //  - In order to avoid any deadlock potential, it is absolutely forbidden to have
        //      any sort of call out from this class while the lock is held. This is why
        //      the draining of the work queue uses a relatively complex pattern.
        private var downstream: Downstream?
        private var childSubscribers = Set<ChildSubscriber>()
        private var downstreamDemand = Subscribers.Demand.unlimited
        private var valuesToSend = [PendingValue]()
        private var queueIsBeingProcessed = false
        private var sendFinishedAfterDrainingQueue = false
        private var upstreamSubscription: Subscription?

        var description: String { return "FlatMap" }

        init(downstream: Downstream,
             maxPublishers: Subscribers.Demand,
             transform: @escaping (Upstream.Output) -> Child) {
            self.downstream = downstream
            self.maxPublishers = maxPublishers
            self.transform = transform
        }

        final func cancel() {

            let (upstreamToCancel, childrenToCancel) = lock
                .do { () -> (Subscription?, Set<ChildSubscriber>) in
                    let upstreamToCancel = upstreamSubscription
                    upstreamSubscription = nil
                    return (upstreamToCancel, lockedDeactivateAndReturnChildrenToCancel())
                }

            upstreamToCancel?.cancel()
            cancelChildren(childrenToCancel)
        }
    }
}

// Private implementation
extension Publishers.FlatMap.Inner {

    private func deactivate() {
        cancelChildren(lock.do(lockedDeactivateAndReturnChildrenToCancel))
    }

    // Must be called with lock held.
    private func lockedDeactivateAndReturnChildrenToCancel() -> Set<ChildSubscriber> {
        downstream = nil
        downstreamDemand = .none
        let result = childSubscribers
        childSubscribers.removeAll()
        upstreamSubscription = nil
        return result
    }

    private func cancelChildren(_ childrenToCancel: Set<ChildSubscriber>) {
        childrenToCancel.forEach { $0.cancel() }
    }

    /// In a thread-safe way, this function performs the passed in work with the lock held
    /// and then checks to see if either upstream or any of the child subscriptions remain
    /// active. If there are no remaining active subscriptions, it enqueues the sending
    /// of `.finished` downstream using the processing queue.
    /// - Parameter lockedWork: block to be formed with the lock held.
    private final func maybeSendFinishedAfterExecutingWork(lockedWork: () -> Void) {
        let shouldProcessQueue: Bool = lock.do {
            lockedWork()
            if childSubscribers.isEmpty && upstreamSubscription == nil {
                sendFinishedAfterDrainingQueue = true
                if !queueIsBeingProcessed {
                    queueIsBeingProcessed = true
                    return true
                }
            }
            return false
        }

        if shouldProcessQueue {
            processQueue()
        }
    }

    private func receivedCompletion(_ completion: Subscribers.Completion<Failure>,
                                    fromChild child: ChildSubscriber) {
        switch completion {
        case .finished:
            removeActiveSubscription(forChild: child)
        case .failure:
            downstream?.receive(completion: completion)
            deactivate()
        }
    }

    private func removeActiveSubscription(forChild child: ChildSubscriber) {
        maybeSendFinishedAfterExecutingWork { childSubscribers.remove(child) }
    }

    private func receivedValue(_ value: Child.Output,
                               fromChild child: ChildSubscriber) -> Subscribers.Demand {
        // When receiving a value from a child, we need to determine what additional
        // demand to return to the child. Apple's logic for this determination is as
        // follows:
        //  - If we are in `.unlimited` mode, we always request `.none` additional
        //      else
        //  - If there is a surplus relative to the demand, we request `.none`
        //      else
        //  - There is not yet a surplus, so request `.max(1)` more from the child

        let (surplusAvailable, processTheQueue): (Bool, Bool) = lock.do {
            // If we already have enough values to satisfy the demand, we "buffer" this
            // child value establishing a surplus.
            if downstreamDemand <= valuesToSend.count {
                valuesToSend.append((value, child))
                return (surplusAvailable: true, processTheQueue: false)
            } else {
                valuesToSend.append((value, nil))
                if queueIsBeingProcessed {
                    return (surplusAvailable: false, processTheQueue: false)
                }
                queueIsBeingProcessed = true
                return (surplusAvailable: false, processTheQueue: true)
            }
        }

        let demandResult = surplusAvailable || demandForChild() == .unlimited
            ? Subscribers.Demand.none
            : .max(1)

        if processTheQueue {
            processQueue()
        }

        return demandResult
    }

    private func demandForChild() -> Subscribers.Demand {
        return downstreamDemand == .unlimited ? .unlimited : .max(1)
    }

    private enum QueueWorkStatus {
        case noWork
        case sendFinish
        case sendValues(values: ArraySlice<PendingValue>)
    }

    private func processQueue() {
        assert(queueIsBeingProcessed)

        // We loop processing the queue in case somebody put stuff on the queue while we
        // were sending values with the lock unlocked.
        while true {
            let work: QueueWorkStatus = lock.do {
                if downstreamDemand == .none || valuesToSend.isEmpty {
                    if sendFinishedAfterDrainingQueue && valuesToSend.isEmpty {
                        return .sendFinish
                    } else {
                        queueIsBeingProcessed = false
                        return .noWork
                    }
                }

                let countToSend = min(valuesToSend.count, downstreamDemand.max ?? .max)
                let result = valuesToSend[0..<countToSend]
                // TODO: Consider an alternative storage to avoid O(n) removeFirst
                valuesToSend.removeFirst(countToSend)
                downstreamDemand -= countToSend
                return .sendValues(values: result)
            }

            guard let downstream = downstream else { return }

            switch work {
            case .noWork:
                return
            case .sendFinish:
                downstream.receive(completion: .finished)
                deactivate()
                return
            case .sendValues(let values):
                var newDemand = Subscribers.Demand.none
                values.forEach {
                    newDemand += downstream.receive($0.value)
                    // pausedChild is present only if the value was buffered and the
                    // child's demand was left at `.none`. In that case, once we send the
                    // buffered value, we need to tell the child to get another value.
                    $0.pausedChild?.request(.max(1))
                }

                if newDemand != .none {
                    lock.do { downstreamDemand += newDemand }
                }
            }
        }
    }
}

// This `Subscriber` implementation is for `FlatMap`'s upstream subscription
extension Publishers.FlatMap.Inner: Subscriber {

    fileprivate func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream?.receive(subscription: self)
        subscription.request(maxPublishers)
    }

    /// Receive a new value from the upstream subscription. A new child subscription
    /// will be made on the `Child` that the input value is transformed into.
    /// - Parameter input: a value to be transformed by `transform`
    fileprivate func receive(_ input: Input) -> Subscribers.Demand {
        let newChildSubscriber = ChildSubscriber(parent: self)

        lock.do { _ = childSubscribers.insert(newChildSubscriber) }

        self.transform(input).subscribe(newChildSubscriber)

        return .none
    }

    fileprivate func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .finished:
            maybeSendFinishedAfterExecutingWork { upstreamSubscription = nil }
        case .failure:
            downstream?.receive(completion: completion)
            deactivate()
        }
    }
}

// Inner is the `Subscription` for `Downstream`
extension Publishers.FlatMap.Inner: Subscription {
    fileprivate func request(_ demand: Subscribers.Demand) {
        let (drainTheQueue, becameUnlimited) = lock.do { () -> (Bool, Bool) in
            let becameUnlimited = demand == .unlimited && downstreamDemand != .unlimited
            downstreamDemand = demand
            defer { queueIsBeingProcessed = true }
            return (!queueIsBeingProcessed, becameUnlimited)
        }

        if becameUnlimited {
            // TODO: This code isn't yet thread safe. The correct change is to do this
            // through the queue just like sending values and finished. Finished is
            // done through the queue as a bit of a hack. The right design is to have
            // an enum of actions on the queue. That enum will include (send value,
            // send finished, set child demand).
            let newChildDemand = demandForChild()
            childSubscribers.forEach { $0.request(newChildDemand) }
        }

        if drainTheQueue {
            processQueue()
        }
    }
}

extension Publishers.FlatMap.Inner {
    /// ChildSubscriber is needed to help implement the backpressure/demand strategy.
    /// Specifically, a custom subscriber is needed to manage the demand of the child
    /// subscription:
    ///  - Send .max(1) request when the subscription is received
    ///  - Send .max(1) request when downstream subscriber demands more and a previously
    ///   buffered value from the child was sent. (When the value was buffered, the
    ///   child's demand reached .none - effectively pausing the child.)
    fileprivate final class ChildSubscriber: Hashable {
        internal typealias Input = Downstream.Input
        internal typealias Failure = Downstream.Failure

        private var _upstreamSubscription: Subscription?
        private unowned let _parent: Publishers.FlatMap<Child, Upstream>.Inner<Downstream>

        init(parent: Publishers.FlatMap<Child, Upstream>.Inner<Downstream>) {
            _parent = parent
        }

        fileprivate func request(_ demand: Subscribers.Demand) {
            _upstreamSubscription?.request(demand)
        }

        public static func == (lhs: ChildSubscriber, rhs: ChildSubscriber) -> Bool {
            return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
    }
}

extension Publishers.FlatMap.Inner.ChildSubscriber: Cancellable {
    fileprivate func cancel() {
        _upstreamSubscription?.cancel()
        _upstreamSubscription = nil
    }
}

extension Publishers.FlatMap.Inner.ChildSubscriber: Subscriber {

    fileprivate func receive(subscription: Subscription) {
        if _upstreamSubscription == nil {
            _upstreamSubscription = subscription
            subscription.request(_parent.demandForChild())
        } else {
            assertionFailure()
            subscription.cancel()
        }
    }

    fileprivate func receive(_ input: Input) -> Subscribers.Demand {
        return _parent.receivedValue(input, fromChild: self)
    }

    fileprivate func receive(completion: Subscribers.Completion<Failure>) {
        _parent.receivedCompletion(completion, fromChild: self)
    }
}
