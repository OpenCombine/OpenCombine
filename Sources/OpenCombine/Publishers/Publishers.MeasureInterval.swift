//
//  Publishers.MeasureInterval.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.12.2019.
//

extension Publisher {

    /// Measures and emits the time interval between events received from an upstream
    /// publisher.
    ///
    /// Use `measureInterval(using:options:)` to measure the time between events delivered
    /// from an upstream publisher.
    ///
    /// In the example below, a 1-second `Timer` is used as the data source for an event
    /// publisher; the `measureInterval(using:options:)` operator reports the elapsed time
    /// between the reception of events on the main run loop:
    ///
    ///     cancellable = Timer.publish(every: 1, on: .main, in: .default)
    ///         .autoconnect()
    ///         .measureInterval(using: RunLoop.main)
    ///         .sink { print("\($0)", terminator: "\n") }
    ///
    ///     // Prints:
    ///     //      Stride(magnitude: 1.0013610124588013)
    ///     //      Stride(magnitude: 0.9992760419845581)
    ///
    /// The output type of the returned publisher is the time interval of the provided
    /// scheduler.
    ///
    /// This operator uses the provided scheduler’s `now` property to measure intervals
    /// between events.
    ///
    /// - Parameters:
    ///   - scheduler: A scheduler to use for tracking the timing of events.
    ///   - options: Options that customize the delivery of elements.
    /// - Returns: A publisher that emits elements representing the time interval between
    ///   the elements it receives.
    public func measureInterval<Context: Scheduler>(
        using scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.MeasureInterval<Self, Context> {
        return .init(upstream: self, scheduler: scheduler)
    }
}

extension Publishers {

    /// A publisher that measures and emits the time interval between events received from
    /// an upstream publisher.
    public struct MeasureInterval<Upstream: Publisher, Context: Scheduler>: Publisher {

        public typealias Output = Context.SchedulerTimeType.Stride

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The scheduler used for tracking the timing of events.
        public let scheduler: Context

        /// Creates a publisher that measures and emits the time interval between events
        /// received from an upstream publisher.
        ///
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        ///   - scheduler: A scheduler to use for tracking the timing of events.
        public init(upstream: Upstream, scheduler: Context) {
            self.upstream = upstream
            self.scheduler = scheduler
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Downstream.Input == Context.SchedulerTimeType.Stride
        {
            upstream.subscribe(Inner(scheduler: scheduler, downstream: subscriber))
        }
    }
}

extension Publishers.MeasureInterval {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Context.SchedulerTimeType.Stride,
              Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let lock = UnfairLock.allocate()

        private let downstream: Downstream

        private let scheduler: Context

        private var state = SubscriptionStatus.awaitingSubscription

        private var last: Context.SchedulerTimeType?

        init(scheduler: Context, downstream: Downstream) {
            self.downstream = downstream
            self.scheduler = scheduler
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            last = scheduler.now
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(subscription) = state,
                  let previousTime = last else
            {
                lock.unlock()
                return .none
            }
            let now = scheduler.now
            last = now
            lock.unlock()
            let newDemand = downstream.receive(previousTime.distance(to: now))
            if newDemand > 0 {
                subscription.request(newDemand)
            }
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            state = .terminal
            last = nil
            lock.unlock()
            downstream.receive(completion: completion)
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
            last = nil
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "MeasureInterval" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
