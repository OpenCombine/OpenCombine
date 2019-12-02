//
//  Publishers.Delay.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 07/09/2019.
//

extension Publishers {

    /// A publisher that delays delivery of elements and completion
    /// to the downstream receiver.
    public struct Delay<Upstream, Context>: Publisher
        where Upstream: Publisher, Context: Scheduler {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
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

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
            Upstream.Output == Downstream.Input
        {
            let inner: Inner<Upstream, Downstream> = Inner(downstream: subscriber,
                                                           upstream: upstream,
                                                           interval: interval,
                                                           tolerance: tolerance,
                                                           scheduler: scheduler,
                                                           options: options)
            scheduler.schedule {
                self.upstream.subscribe(inner)
            }
        }
    }
}

extension Publishers.Delay {

    private final class Inner<Upstream: Publisher, Downstream: Subscriber>
          : OperatorSubscription<Downstream>,
            CustomStringConvertible,
            Subscriber
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        typealias Transform = (Input) -> Result<Downstream.Input, Downstream.Failure>

        let interval: Context.SchedulerTimeType.Stride
        let tolerance: Context.SchedulerTimeType.Stride
        let scheduler: Context
        let options: Context.SchedulerOptions?

        init(downstream: Downstream,
             upstream: Upstream,
             interval: Context.SchedulerTimeType.Stride,
             tolerance: Context.SchedulerTimeType.Stride,
             scheduler: Context,
             options: Context.SchedulerOptions?) {
            self.interval = interval
            self.tolerance = Swift.min(scheduler.minimumTolerance, tolerance)
            self.scheduler = scheduler
            self.options = options
            self.isCompleted = false
            super.init(downstream: downstream)
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            if isCompleted {
                return .none
            }
            let date = scheduler.now.advanced(by: interval)

            scheduler.schedule(after: date,
                               tolerance: tolerance,
                               options: options,
                               { [weak self] in
                guard let strongSelf = self,
                    strongSelf.isCompleted == false else  {
                    return
                }
                _ = strongSelf.downstream?.receive(input)
            })
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            isCompleted = true
            downstream.receive(completion: completion)
        }

        override func cancel() {
            isCompleted = true
            super.cancel()
        }

        var description: String { return "Delay" }
        private var isCompleted: Bool
    }
}
