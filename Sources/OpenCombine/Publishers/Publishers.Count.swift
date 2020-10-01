//
//  Publishers.Count.swift
//
//
//  Created by Joseph Spadafora on 6/25/19.
//

extension Publisher {

    /// Publishes the number of elements received from the upstream publisher.
    ///
    /// Use `count(`` to determine the number of elements received from the upstream
    /// publisher before it completes:
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .count()
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "11"
    ///
    /// - Returns: A publisher that consumes all elements until the upstream publisher
    ///   finishes, then emits a single value with the total number of elements received.
    public func count() -> Publishers.Count<Self> {
        return Publishers.Count(upstream: self)
    }
}

extension Publishers {

    /// A publisher that publishes the number of elements received
    /// from the upstream publisher.
    public struct Count<Upstream: Publisher>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Int

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
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
                  Downstream.Input == Output
        {
            upstream.subscribe(Inner(downstream: subscriber))
        }
    }
}

extension Publishers.Count: Equatable where Upstream: Equatable {}

extension Publishers.Count {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream, Upstream.Output, Int, Failure, Void>
        where Downstream.Input == Int,
              Upstream.Failure == Downstream.Failure
    {
        fileprivate init(downstream: Downstream) {
            super.init(downstream: downstream, initial: 0, reduce: ())
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            result! += 1
            return .continue
        }

        override var description: String { return "Count" }
    }
}
