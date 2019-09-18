//
//  Publishers.MapError.swift
//  
//
//  Created by Joseph Spadafora on 7/4/19.
//

extension Publishers {

    /// A publisher that converts any failure from the
    /// upstream publisher into a new error.
    public struct MapError<Upstream: Publisher, Failure: Error>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that converts the upstream failure into a new error.
        public let transform: (Upstream.Failure) -> Failure

        public init(upstream: Upstream, _ map: @escaping (Upstream.Failure) -> Failure) {
            self.upstream = upstream
            self.transform = map
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, transform: transform))
        }
    }
}

extension Publisher {

    /// Converts any failure from the upstream publisher into a new error.
    ///
    /// Until the upstream publisher finishes normally or fails with an error,
    /// the returned publisher republishes all the elements it receives.
    ///
    /// - Parameter transform: A closure that takes the upstream failure as a
    /// parameter and returns a new error for the publisher to terminate with.
    /// - Returns: A publisher that replaces any upstream failure with a
    /// new error produced by the `transform` closure.
    public func mapError<NewFailure: Error>(
        _ transform: @escaping (Self.Failure) -> NewFailure
    ) -> Publishers.MapError<Self, NewFailure>
    {
        return Publishers.MapError(upstream: self, transform)
    }
}

extension Publishers.MapError {

    private final class Inner<Downstream: Subscriber>
        : OperatorSubscription<Downstream>,
          Subscriber,
          CustomStringConvertible
        where Upstream.Output == Downstream.Input
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        typealias Output = Downstream.Input

        private let _transform: (Upstream.Failure) -> Downstream.Failure

        var description: String { return "MapError" }

        init(downstream: Downstream,
             transform: @escaping (Upstream.Failure) -> Downstream.Failure) {
            self._transform = transform
            super.init(downstream: downstream)
        }

        func receive(subscription: Subscription) {
            upstreamSubscription = subscription
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case .failure(let error):
                downstream.receive(completion: .failure(_transform(error)))
            }
        }
    }
}
