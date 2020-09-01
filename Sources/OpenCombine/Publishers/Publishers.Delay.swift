//
//  Publishers.Delay.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 07/09/2019.
//

extension Publisher {

    /// Delays delivery of all output to the downstream receiver by a specified amount
    /// of time on a particular scheduler.
    ///
    /// The delay affects the delivery of elements and completion, but not of the original
    /// subscription.
    ///
    /// - Parameters:
    ///   - interval: The amount of time to delay.
    ///   - tolerance: The allowed tolerance in firing delayed events.
    ///   - scheduler: The scheduler to deliver the delayed events.
    /// - Returns: A publisher that delays delivery of elements and completion to
    ///   the downstream receiver.
    public func delay<Context: Scheduler>(
        for interval: Context.SchedulerTimeType.Stride,
        tolerance: Context.SchedulerTimeType.Stride? = nil,
        scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.Delay<Self, Context> {
        return .init(upstream: self,
                     interval: interval,
                     tolerance: tolerance ?? scheduler.minimumTolerance,
                     scheduler: scheduler,
                     options: options)
    }
}

extension Publishers {

    /// A publisher that delays delivery of elements and completion
    /// to the downstream receiver.
    public struct Delay<Upstream: Publisher, Context: Scheduler>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// The amount of time to delay.
        public let interval: Context.SchedulerTimeType.Stride

        /// The allowed tolerance in firing delayed events.
        public let tolerance: Context.SchedulerTimeType.Stride

        /// The scheduler to deliver the delayed events.
        public let scheduler: Context

        public let options: Context.SchedulerOptions?

        public init(upstream: Upstream,
                    interval: Context.SchedulerTimeType.Stride,
                    tolerance: Context.SchedulerTimeType.Stride,
                    scheduler: Context,
                    options: Context.SchedulerOptions? = nil)
        {
            self.upstream = upstream
            self.interval = interval
            self.tolerance = tolerance
            self.scheduler = scheduler
            self.options = options
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber,
                              interval: interval,
                              tolerance: tolerance,
                              scheduler: scheduler,
                              options: options)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Delay {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let lock = UnfairLock.allocate()
        private let downstream: Downstream
        private let interval: Context.SchedulerTimeType.Stride
        private let tolerance: Context.SchedulerTimeType.Stride
        private let scheduler: Context
        private let options: Context.SchedulerOptions?
        private var state = SubscriptionStatus.awaitingSubscription
        private let downstreamLock = UnfairRecursiveLock.allocate()

        fileprivate init(downstream: Downstream,
                         interval: Context.SchedulerTimeType.Stride,
                         tolerance: Context.SchedulerTimeType.Stride,
                         scheduler: Context,
                         options: Context.SchedulerOptions?) {
            self.downstream = downstream
            self.interval = interval
            self.tolerance = tolerance
            self.scheduler = scheduler
            self.options = options
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        private func schedule(_ work: @escaping () -> Void) {
            scheduler
                .schedule(after: scheduler.now.advanced(by: interval),
                          tolerance: tolerance,
                          options: options,
                          work)
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
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            schedule {
                self.scheduledReceive(input)
            }
            return .none
        }

        private func scheduledReceive(_ input: Input) {
            lock.lock()
            guard state.subscription != nil else {
                lock.unlock()
                return
            }
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            if newDemand == .none { return }
            lock.lock()
            let subscription = state.subscription
            lock.unlock()
            subscription?.request(newDemand)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            state = .pendingTerminal(subscription)
            lock.unlock()
            schedule {
                self.scheduledReceive(completion: completion)
            }
        }

        private func scheduledReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .pendingTerminal = state else {
                assertionFailure(
                    "This branch should not be reachable! Please report a bug."
                )
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subscription.cancel()
        }
    }
}
