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
            upstream.subscribe(Inner(self, downstream: subscriber))
        }
    }
}

extension Publishers.Delay {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        // NOTE: This class has been audited for thread safety

        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        fileprivate typealias Delay = Publishers.Delay<Upstream, Context>

        private enum State {
            case ready(Delay, Downstream)
            case subscribed(Delay, Downstream, Subscription)
            case terminal
        }

        private let lock = UnfairLock.allocate()
        private var state: State
        private let downstreamLock = UnfairRecursiveLock.allocate()

        fileprivate init(_ publisher: Delay, downstream: Downstream) {
            state = .ready(publisher, downstream)
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        private func schedule(_ delay: Delay, work: @escaping () -> Void) {
            delay
                .scheduler
                .schedule(after: delay.scheduler.now.advanced(by: delay.interval),
                          tolerance: delay.tolerance,
                          options: delay.options,
                          work)
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(delay, downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(delay, downstream, subscription)
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(subscription: self)
            downstreamLock.unlock()
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(delay, downstream, _) = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            schedule(delay) {
                self.scheduledReceive(input, downstream: downstream)
            }
            return .none
        }

        private func scheduledReceive(_ input: Upstream.Output, downstream: Downstream) {
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            guard newDemand > 0 else {
                return
            }
            lock.lock()
            guard case let .subscribed(_, _, subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(newDemand)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case let .subscribed(delay, downstream, _) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            schedule(delay) {
                self.scheduledReceive(completion: completion, downstream: downstream)
            }
        }

        private func scheduledReceive(completion: Subscribers.Completion<Failure>,
                                      downstream: Downstream) {
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(_, _, subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(_, _, subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subscription.cancel()
        }
    }
}
