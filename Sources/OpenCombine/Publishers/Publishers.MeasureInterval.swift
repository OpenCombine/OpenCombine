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
    /// The output type of the returned scheduler is the time interval of the provided
    /// scheduler.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler on which to deliver elements.
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

        /// The scheduler on which to deliver elements.
        public let scheduler: Context

        public init(upstream: Upstream, scheduler: Context) {
            self.upstream = upstream
            self.scheduler = scheduler
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Downstream.Input == Context.SchedulerTimeType.Stride
        {
            upstream.subscribe(Inner(self, downstream: subscriber))
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
        // NOTE: This class has been audited for thread safety

        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        typealias MeasureInterval = Publishers.MeasureInterval<Upstream, Context>

        private enum State {
            case ready(MeasureInterval, Downstream)
            case subscribed(MeasureInterval, Downstream, Subscription)
            case terminal
        }

        private let lock = UnfairLock.allocate()

        private var state: State

        private var last: Context.SchedulerTimeType?

        init(_ measureInterval: MeasureInterval, downstream: Downstream) {
            state = .ready(measureInterval, downstream)
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(measureInterval, downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(measureInterval, downstream, subscription)
            last = measureInterval.scheduler.now
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(measureInterval, downstream, subscription) = state,
                  let previousTime = last else {
                lock.unlock()
                return .none
            }
            let now = measureInterval.scheduler.now
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
            guard case let .subscribed(_, downstream, _) = state else {
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
            last = nil
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "MeasureInterval" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
