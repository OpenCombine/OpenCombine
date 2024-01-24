// This file contains parts of Apple's Combine that remain unimplemented in OpenCombine
// Please remove the corresponding piece from this file if you implement something,
// and complement this file as features are added in Apple's Combine

extension Publishers {

    /// A strategy for collecting received elements.
    public enum TimeGroupingStrategy<Context> where Context : Scheduler {

        /// A grouping that collects and periodically publishes items.
        case byTime(Context, Context.SchedulerTimeType.Stride)

        /// A grouping that collects and publishes items periodically or when a buffer reaches a maximum size.
        case byTimeOrCount(Context, Context.SchedulerTimeType.Stride, Int)
    }

    /// A publisher that buffers and periodically publishes its items.
    public struct CollectByTime<Upstream, Context> : Publisher where Upstream : Publisher, Context : Scheduler {

        /// The kind of values published by this publisher.
        public typealias Output = [Upstream.Output]

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// The strategy with which to collect and publish elements.
        public let strategy: Publishers.TimeGroupingStrategy<Context>

        /// `Scheduler` options to use for the strategy.
        public let options: Context.SchedulerOptions?

        public init(upstream: Upstream, strategy: Publishers.TimeGroupingStrategy<Context>, options: Context.SchedulerOptions?)

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Failure == S.Failure, S.Input == [Upstream.Output]
    }
}

extension Publisher {

    /// Collects elements by a given time-grouping strategy, and emits a single array of
    /// the collection.
    ///
    /// Use `collect(_:options:)` to emit arrays of elements on a schedule specified by
    /// a `Scheduler` and `Stride` that you provide. At the end of each scheduled
    /// interval, the publisher sends an array that contains the items it collected.
    /// If the upstream publisher finishes before filling the buffer, the publisher sends
    /// an array that contains items it received. This may be fewer than the number of
    /// elements specified in the requested `Stride`.
    ///
    /// If the upstream publisher fails with an error, this publisher forwards the error
    /// to the downstream receiver instead of sending its output.
    ///
    /// The example above collects timestamps generated on a one-second `Timer` in groups
    /// (`Stride`) of five.
    ///
    ///     let sub = Timer.publish(every: 1, on: .main, in: .default)
    ///         .autoconnect()
    ///         .collect(.byTime(RunLoop.main, .seconds(5)))
    ///         .sink { print("\($0)", terminator: "\n\n") }
    ///
    ///     // Prints: "[2020-01-24 00:54:46 +0000, 2020-01-24 00:54:47 +0000,
    ///     //          2020-01-24 00:54:48 +0000, 2020-01-24 00:54:49 +0000,
    ///     //          2020-01-24 00:54:50 +0000]"
    ///
    /// > Note: When this publisher receives a request for `.max(n)` elements, it requests
    /// `.max(count * n)` from the upstream publisher.
    ///
    /// - Parameters:
    ///   - strategy: The timing group strategy used by the operator to collect and
    ///     publish elements.
    ///   - options: ``Scheduler`` options to use for the strategy.
    /// - Returns: A publisher that collects elements by a given strategy, and emits
    ///   a single array of the collection.
    public func collect<S>(_ strategy: Publishers.TimeGroupingStrategy<S>, options: S.SchedulerOptions? = nil) -> Publishers.CollectByTime<Self, S> where S : Scheduler
}
