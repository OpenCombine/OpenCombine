//
//  Publishers.Debounce.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.12.2019.
//

extension Publisher {

    /// Publishes elements only after a specified time interval elapses between events.
    ///
    /// Use this operator when you want to wait for a pause in the delivery of events from
    /// the upstream publisher. For example, call `debounce` on the publisher from a text
    /// field to only receive elements when the user pauses or stops typing. When they
    /// start typing again, the `debounce` holds event delivery until the next pause.
    ///
    /// - Parameters:
    ///   - dueTime: The time the publisher should wait before publishing an element.
    ///   - scheduler: The scheduler on which this publisher delivers elements
    ///   - options: Scheduler options that customize this publisher’s delivery
    ///     of elements.
    /// - Returns: A publisher that publishes events only after a specified time elapses.
    public func debounce<Context: Scheduler>(
        for dueTime: Context.SchedulerTimeType.Stride,
        scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.Debounce<Self, Context> {
        return .init(upstream: self,
                     dueTime: dueTime,
                     scheduler: scheduler,
                     options: options)
    }
}

extension Publishers {

    /// A publisher that publishes elements only after a specified time interval elapses
    /// between events.
    public struct Debounce<Upstream: Publisher, Context: Scheduler>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The amount of time the publisher should wait before publishing an element.
        public let dueTime: Context.SchedulerTimeType.Stride

        /// The scheduler on which this publisher delivers elements.
        public let scheduler: Context

        /// Scheduler options that customize this publisher’s delivery of elements.
        public let options: Context.SchedulerOptions?

        public init(upstream: Upstream,
                    dueTime: Context.SchedulerTimeType.Stride,
                    scheduler: Context,
                    options: Context.SchedulerOptions?) {
            self.upstream = upstream
            self.dueTime = dueTime
            self.scheduler = scheduler
            self.options = options
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure, Downstream.Input == Output
        {
            let inner = Inner(downstream: subscriber,
                              dueTime: dueTime,
                              scheduler: scheduler,
                              options: options)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Debounce {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input,
              Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private typealias Generation = UInt64

        private let lock = UnfairLock.allocate()

        private let downstreamLock = UnfairRecursiveLock.allocate()

        private let downstream: Downstream

        private let dueTime: Context.SchedulerTimeType.Stride

        private let scheduler: Context

        private let options: Context.SchedulerOptions?

        private var state = SubscriptionStatus.awaitingSubscription

        private var currentCanceller: Cancellable?

        private var currentValue: Output?

        private var currentGeneration: Generation = 0

        private var downstreamDemand = Subscribers.Demand.none

        init(downstream: Downstream,
             dueTime: Context.SchedulerTimeType.Stride,
             scheduler: Context,
             options: Context.SchedulerOptions?) {
            self.downstream = downstream
            self.dueTime = dueTime
            self.scheduler = scheduler
            self.options = options
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(subscription: self)
            downstreamLock.unlock()
            subscription.request(.unlimited)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            precondition(!state.isAwaigingSubscription)
            guard case .subscribed = state else {
                lock.unlock()
                return .none
            }
            currentGeneration += 1
            let generation = currentGeneration
            currentValue = input
            let due = scheduler.now.advanced(by: dueTime)
            lock.unlock()
            let newCanceller = scheduler.schedule(after: due,
                                                  interval: dueTime,
                                                  tolerance: scheduler.minimumTolerance,
                                                  options: options) { [weak self] in
                self?.due(generation: generation)
            }
            lock.lock()
            let canceller = currentCanceller
            currentCanceller = newCanceller
            lock.unlock()
            canceller?.cancel()
            return .none
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            precondition(!state.isAwaigingSubscription)
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            state = .terminal
            let canceller = currentCanceller
            lock.unlock()
            canceller?.cancel()
            scheduler.schedule {
                self.downstreamLock.lock()
                self.downstream.receive(completion: completion)
                self.downstreamLock.unlock()
            }
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            precondition(!state.isAwaigingSubscription)
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            downstreamDemand += demand
            lock.unlock()
        }

        func cancel() {
            lock.lock()
            guard case .subscribed(let subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "Debounce" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("downstreamDemand", downstreamDemand),
                ("currentValue", currentValue as Any)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }

        private func due(generation: Generation) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }

            // If this condition holds, it means that no values were received
            // in this time frame => we should propagate the current value downstream.
            guard generation == currentGeneration, let value = currentValue else {
                let canceller = currentCanceller
                lock.unlock()
                canceller?.cancel()
                return
            }

            let hasAnyDemand = downstreamDemand > 0
            if hasAnyDemand {
                downstreamDemand -= 1
            }

            let canceller = currentCanceller!
            lock.unlock()
            canceller.cancel()

            guard hasAnyDemand else { return }

            downstreamLock.lock()
            let newDemand = downstream.receive(value)
            downstreamLock.unlock()

            if newDemand == .none { return }

            lock.lock()
            downstreamDemand += newDemand
            lock.unlock()
        }
    }
}
