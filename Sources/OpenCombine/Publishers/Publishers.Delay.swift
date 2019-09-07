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
            scheduler.schedule {
                self._receive(subscriber: subscriber)
            }
        }

        private func _receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
            Upstream.Output == Downstream.Input
        {
            let scheduler = self.scheduler
            let interval = self.interval
            let tolerance = self.tolerance

            let delayedPublisher = upstream.flatMap
                { output -> PassthroughSubject<Output, Failure> in

                let object: PassthroughSubject<Output, Failure> = .init()
                let date = scheduler.now.advanced(by: interval)
                let tolerance = Swift.min(scheduler.minimumTolerance, tolerance)

                scheduler.schedule(after: date,
                                   tolerance: tolerance,
                                   options: self.options,
                                   {
                    object.send(output)
                })
                return object
            }
            delayedPublisher.subscribe(subscriber)
        }
    }
}

// MARK: A cap is required until the "FlatMap" is accessible
extension Publishers {
    public struct FlatMap<NewPublisher, Upstream>: Publisher
        where NewPublisher: Publisher, Upstream: Publisher,
        NewPublisher.Failure == Upstream.Failure {

        public typealias Output = NewPublisher.Output
        public typealias Failure = Upstream.Failure

        public let upstream: Upstream

        public let maxPublishers: Subscribers.Demand

        public let transform: (Upstream.Output) -> NewPublisher

        public init(upstream: Upstream,
                    maxPublishers: Subscribers.Demand,
                    transform: @escaping (Upstream.Output) -> NewPublisher) {
            self.upstream = upstream
            self.maxPublishers = maxPublishers
            self.transform = transform
        }

        public func receive<SubscriberType>(subscriber: SubscriberType)
            where SubscriberType: Subscriber,
            NewPublisher.Output == SubscriberType.Input,
            Upstream.Failure == SubscriberType.Failure {
        }
    }
}

// MARK: A cap is required until the "FlatMap" is accessible
extension Publisher {
    public func flatMap<TypeIn, TypeOut>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (Self.Output) -> TypeOut)
        -> Publishers.FlatMap<TypeOut, Self>
        where TypeIn == TypeOut.Output, TypeOut: Publisher,
        Self.Failure == TypeOut.Failure {
        fatalError()
    }
}
