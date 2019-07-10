//
//  Publishers.Last.swift
//  
//
//  Created by Joseph Spadafora on 7/9/19.
//

import Foundation

extension Publishers {

    /// A publisher that only publishes the last element of a stream,
    /// after the stream finishes.
    public struct Last<Upstream: Publisher>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

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
        public func receive<SubscriberType: Subscriber>(
            subscriber: SubscriberType
        ) where Failure == SubscriberType.Failure,
                Output == SubscriberType.Input
        {
            let lastSubscriber = _Last<Upstream, SubscriberType>(downstream: subscriber)
            upstream.receive(subscriber: lastSubscriber)
        }
    }
}

private final class _Last<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscriber,
      CustomStringConvertible,
      Subscription
    where Upstream.Output == Downstream.Input,
          Upstream.Failure == Downstream.Failure
{

    typealias Input = Upstream.Output
    typealias Output = Input
    typealias Failure = Downstream.Failure

    var description: String { return "Last" }

    private var lastValue: Output?
    private var isFinished = false

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
        upstreamSubscription?.request(.unlimited)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        lastValue = input
        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        guard !isFinished else { return }
        if case .finished = completion, let value = lastValue {
            _ = downstream.receive(value)
        }
        downstream.receive(completion: completion)
        isFinished = true
    }

    func request(_ demand: Subscribers.Demand) {
    }
}

extension Publisher {

    /// Only publishes the last element of a stream, after the stream finishes.
    /// - Returns: A publisher that only publishes the last element of a stream.
    public func last() -> Publishers.Last<Self> {
        return Publishers.Last(upstream: self)
    }
}
