//
//  Publishers.IgnoreOutput.swift
//
//  Created by Eric Patey on 16.08.2019.
//

extension Publisher {

    /// Ingores all upstream elements, but passes along a completion
    /// state (finished or failed).
    ///
    /// The output type of this publisher is `Never`.
    /// - Returns: A publisher that ignores all upstream elements.
    public func ignoreOutput() -> Publishers.IgnoreOutput<Self> {
        return Publishers.IgnoreOutput(upstream: self)
    }
}

extension Publishers {
    /// A publisher that ignores all upstream elements, but passes along a completion
    /// state (finish or failed).
    public struct IgnoreOutput<Upstream: Publisher>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Never

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
            where Downstream.Failure == Upstream.Failure, Downstream.Input == Never {
            let inner = Inner<Downstream>(downstream: subscriber)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.IgnoreOutput {

    private final class Inner<Downstream: Subscriber>
        : OperatorSubscription<Downstream>,
          Subscriber,
          CustomStringConvertible,
          Subscription
    where Downstream.Input == Never,
          Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Output = Never
        typealias Failure = Upstream.Failure

        var description: String { return "IgnoreOutput" }

        func receive(subscription: Subscription) {
            upstreamSubscription = subscription
            downstream.receive(subscription: self)
            subscription.request(.unlimited)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            // ignore and requests from downstream since we'll never send
            // any values
        }
    }
}

extension Publishers.IgnoreOutput: Equatable where Upstream: Equatable {}
