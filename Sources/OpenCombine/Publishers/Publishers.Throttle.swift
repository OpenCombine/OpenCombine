//
//  Publishers.Throttle.swift
//  
//
//  Created by Stuart Austin on 14/11/2020.
//

extension Publisher {
    // swiftlint:disable generic_type_name line_length

    /// Publishes either the most-recent or first element published by the upstream
    /// publisher in the specified time interval.
    ///
    /// Use `throttle(for:scheduler:latest:`` to selectively republish elements from
    /// an upstream publisher during an interval you specify. Other elements received from
    /// the upstream in the throttling interval aren’t republished.
    ///
    /// In the example below, a `Timer.TimerPublisher` produces elements on 3-second
    /// intervals; the `throttle(for:scheduler:latest:)` operator delivers the first
    /// event, then republishes only the latest event in the following ten second
    /// intervals:
    ///
    ///     cancellable = Timer.publish(every: 3.0, on: .main, in: .default)
    ///         .autoconnect()
    ///         .print("\(Date().description)")
    ///         .throttle(for: 10.0, scheduler: RunLoop.main, latest: true)
    ///         .sink(
    ///             receiveCompletion: { print ("Completion: \($0).") },
    ///             receiveValue: { print("Received Timestamp \($0).") }
    ///          )
    ///
    ///     // Prints:
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:26:57 +0000)
    ///     //    Received Timestamp 2020-03-19 18:26:57 +0000.
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:27:00 +0000)
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:27:03 +0000)
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:27:06 +0000)
    ///     //    Publish at: 2020-03-19 18:26:54 +0000: receive value: (2020-03-19 18:27:09 +0000)
    ///     //    Received Timestamp 2020-03-19 18:27:09 +0000.
    ///
    /// - Parameters:
    ///   - interval: The interval at which to find and emit either the most recent or
    ///     the first element, expressed in the time system of the scheduler.
    ///   - scheduler: The scheduler on which to publish elements.
    ///   - latest: A Boolean value that indicates whether to publish the most recent
    ///     element. If `false`, the publisher emits the first element received during
    ///     the interval.
    /// - Returns: A publisher that emits either the most-recent or first element received
    ///   during the specified interval.
    public func throttle<S>(for interval: S.SchedulerTimeType.Stride,
                            scheduler: S,
                            latest: Bool) -> Publishers.Throttle<Self, S>
    where S: Scheduler
    {
        return .init(upstream: self,
                     interval: interval,
                     scheduler: scheduler,
                     latest: latest)
    }

    // swiftlint:enable generic_type_name line_length
}

extension Publishers {

    /// A publisher that publishes either the most-recent or first element published by
    /// the upstream publisher in a specified time interval.
    public struct Throttle<Upstream, Context>: Publisher
    where Upstream: Publisher, Context: Scheduler
    {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The interval in which to find and emit the most recent element.
        public let interval: Context.SchedulerTimeType.Stride

        /// The scheduler on which to publish elements.
        public let scheduler: Context

        /// A Boolean value indicating whether to publish the most recent element.
        ///
        /// If `false`, the publisher emits the first element received during
        /// the interval.
        public let latest: Bool

        public init(upstream: Upstream,
                    interval: Context.SchedulerTimeType.Stride,
                    scheduler: Context,
                    latest: Bool) {

            self.upstream = upstream
            self.interval = interval
            self.scheduler = scheduler
            self.latest = latest
        }

        // swiftlint:disable generic_type_name

        /// Attaches the specified subscriber to this publisher.
        ///
        /// Implementations of ``Publisher`` must implement this method.
        ///
        /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls
        /// this method.
        ///
        /// - Parameter subscriber: The subscriber to attach to this ``Publisher``,
        ///     after which it can receive values.
        public func receive<S>(subscriber: S)
        where S: Subscriber, Upstream.Failure == S.Failure, Upstream.Output == S.Input
        {
            let inner = Inner(interval: interval,
                              scheduler: scheduler,
                              latest: latest,
                              downstream: subscriber)
            upstream.subscribe(inner)
        }

        // swiftlint:enable generic_type_name
    }
}

extension Publishers.Throttle {
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private enum State {
            case awaitingSubscription(Downstream)
            case subscribed(Subscription, Downstream)
            case pendingTerminal(Subscription, Downstream)
            case terminal
        }

        private let lock = UnfairLock.allocate()
        private let interval: Context.SchedulerTimeType.Stride
        private let scheduler: Context
        private let latest: Bool
        private var state: State
        private let downstreamLock = UnfairRecursiveLock.allocate()

        private var lastEmissionTime: Context.SchedulerTimeType?

        private var pendingInput: Input?
        private var pendingCompletion: Subscribers.Completion<Failure>?

        private var demand: Subscribers.Demand = .none

        private var lastTime: Context.SchedulerTimeType

        init(interval: Context.SchedulerTimeType.Stride,
             scheduler: Context,
             latest: Bool,
             downstream: Downstream) {
            self.state = .awaitingSubscription(downstream)
            self.interval = interval
            self.scheduler = scheduler
            self.latest = latest

            self.lastTime = scheduler.now
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .awaitingSubscription(downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            self.lastTime = scheduler.now

            state = .subscribed(subscription, downstream)
            lock.unlock()

            subscription.request(.unlimited)

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

            let lastTime = scheduler.now
            self.lastTime = lastTime

            guard demand > .none else {
                lock.unlock()
                return .none
            }

            let hasScheduledOutput = (pendingInput != nil || pendingCompletion != nil)

            if hasScheduledOutput && latest {
                pendingInput = input
                lock.unlock()
            } else if !hasScheduledOutput {
                let minimumEmissionTime =
                    lastEmissionTime.map { $0.advanced(by: interval) }

                let emissionTime =
                    minimumEmissionTime.map { Swift.max(lastTime, $0) } ?? lastTime

                demand -= 1

                pendingInput = input
                lock.unlock()

                let action: () -> Void = { [weak self] in
                    self?.scheduledEmission()
                }

                if emissionTime == lastTime {
                    scheduler.schedule(action)
                } else {
                    scheduler.schedule(after: emissionTime, action)
                }
            } else {
                lock.unlock()
            }

            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case let .subscribed(subscription, downstream) = state else {
                lock.unlock()
                return
            }
            let lastTime = scheduler.now
            self.lastTime = lastTime
            state = .pendingTerminal(subscription, downstream)

            let hasScheduledOutput = (pendingInput != nil || pendingCompletion != nil)

            if hasScheduledOutput && pendingCompletion == nil {
                pendingCompletion = completion
                lock.unlock()
            } else if !hasScheduledOutput {
                pendingCompletion = completion
                lock.unlock()

                scheduler.schedule { [weak self] in
                    self?.scheduledEmission()
                }
            } else {
                lock.unlock()
            }
        }

        private func scheduledEmission() {
            lock.lock()

            let downstream: Downstream

            switch state {
            case .awaitingSubscription, .terminal:
                lock.unlock()
                return
            case let .subscribed(_, foundDownstream),
                 let .pendingTerminal(_, foundDownstream):
                downstream = foundDownstream
            }

            if self.pendingInput != nil && self.pendingCompletion == nil {
                lastEmissionTime = scheduler.now
            }

            let pendingInput = self.pendingInput.take()
            let pendingCompletion = self.pendingCompletion.take()

            if pendingCompletion != nil {
                state = .terminal
            }

            lock.unlock()

            downstreamLock.lock()

            let newDemand: Subscribers.Demand
            if let input = pendingInput {
                newDemand = downstream.receive(input)
            } else {
                newDemand = .none
            }

            if let completion = pendingCompletion {
                downstream.receive(completion: completion)
            }
            downstreamLock.unlock()

            guard newDemand > 0 else { return }
            self.lock.lock()
            demand += newDemand
            self.lock.unlock()
        }

        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else { return }
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            self.demand += demand
            lock.unlock()
        }

        func cancel() {
            lock.lock()

            let subscription: Subscription?
            switch state {
            case let .subscribed(existingSubscription, _),
                 let .pendingTerminal(existingSubscription, _):
                subscription = existingSubscription
            case .awaitingSubscription, .terminal:
                subscription = nil
            }

            state = .terminal
            lock.unlock()

            subscription?.cancel()
        }

        var description: String { return "Throttle" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
