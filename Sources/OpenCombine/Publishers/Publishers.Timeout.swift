//
//  Publishers.Timeout.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2020.
//

extension Publisher {

    /// Terminates publishing if the upstream publisher exceeds the specified time
    /// interval without producing an element.
    ///
    /// - Parameters:
    ///   - interval: The maximum time interval the publisher can go without emitting
    ///     an element, expressed in the time system of the scheduler.
    ///   - scheduler: The scheduler to deliver events on.
    ///   - options: Scheduler options that customize the delivery of elements.
    ///   - customError: A closure that executes if the publisher times out.
    ///     The publisher sends the failure returned by this closure to the subscriber as
    ///     the reason for termination.
    /// - Returns: A publisher that terminates if the specified interval elapses with no
    ///   events received from the upstream publisher.
    public func timeout<Context: Scheduler>(
        _ interval: Context.SchedulerTimeType.Stride,
        scheduler: Context,
        options: Context.SchedulerOptions? = nil,
        customError: (() -> Self.Failure)? = nil
    ) -> Publishers.Timeout<Self, Context> {
        return .init(upstream: self,
                     interval: interval,
                     scheduler: scheduler,
                     options: options,
                     customError: customError)
    }
}

extension Publishers {

    public struct Timeout<Upstream: Publisher, Context: Scheduler>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        public let upstream: Upstream

        public let interval: Context.SchedulerTimeType.Stride

        public let scheduler: Context

        public let options: Context.SchedulerOptions?

        public let customError: (() -> Upstream.Failure)?

        public init(upstream: Upstream,
                    interval: Context.SchedulerTimeType.Stride,
                    scheduler: Context,
                    options: Context.SchedulerOptions?,
                    customError: (() -> Publishers.Timeout<Upstream, Context>.Failure)?) {
            self.upstream = upstream
            self.interval = interval
            self.scheduler = scheduler
            self.options = options
            self.customError = customError
        }

        public func receive<Downsteam: Subscriber>(subscriber: Downsteam)
            where Downsteam.Failure == Failure, Downsteam.Input == Output
        {
            let inner = Inner(downstream: subscriber,
                              interval: interval,
                              scheduler: scheduler,
                              options: options,
                              customError: customError)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Timeout {
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

        private let lock = UnfairLock.allocate()

        private let downstreamLock = UnfairRecursiveLock.allocate()

        private let downstream: Downstream

        private let interval: Context.SchedulerTimeType.Stride

        private let scheduler: Context

        private let options: Context.SchedulerOptions?

        private let customError: (() -> Upstream.Failure)?

        private var state = SubscriptionStatus.awaitingSubscription

        private var didTimeout = false

        private var timer: AnyCancellable?

        private var initialDemand = false

        init(downstream: Downstream,
             interval: Context.SchedulerTimeType.Stride,
             scheduler: Context,
             options: Context.SchedulerOptions?,
             customError: (() -> Upstream.Failure)?) {
            self.downstream = downstream
            self.interval = interval
            self.scheduler = scheduler
            self.options = options
            self.customError = customError
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
            timer = timeoutClock()
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(subscription: self)
            downstreamLock.unlock()
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard !didTimeout, case .subscribed = state else {
                lock.unlock()
                return .none
            }
            timer?.cancel()
            didTimeout = false
            timer = timeoutClock()
            lock.unlock()
            scheduler.schedule(options: options) {
                self.scheduledReceive(input)
            }
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            timer?.cancel()
            lock.unlock()
            scheduler.schedule(options: options) {
                self.scheduledReceive(completion: completion)
            }
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            if !initialDemand {
                timer = timeoutClock()
                initialDemand = true
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
            timer?.cancel()
            subscription.cancel()
        }

        var description: String { return "Timeout" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }

        private func timedOut() {
            lock.lock()
            guard !didTimeout, case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            didTimeout = true
            state = .terminal
            lock.unlock()
            subscription.cancel()
            downstreamLock.lock()
            downstream
                .receive(completion: customError.map { .failure($0()) } ?? .finished)
            downstreamLock.unlock()
        }

        private func timeoutClock() -> AnyCancellable {
            let cancellable = scheduler
                .schedule(after: scheduler.now.advanced(by: interval),
                          interval: interval,
                          tolerance: scheduler.minimumTolerance,
                          options: options,
                          timedOut)
            return AnyCancellable(cancellable.cancel)
        }

        private func scheduledReceive(_ input: Input) {
            lock.lock()
            guard !didTimeout, case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            if newDemand != .none {
                subscription.request(newDemand)
            }
        }

        private func scheduledReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }
    }
}
