//
//  Publishers.Count.swift
//
//
//  Created by Joseph Spadafora on 6/25/19.
//

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
            let count = _Count<Upstream, Downstream>(downstream: subscriber)
            upstream.subscribe(count)
        }
    }
}

extension Publisher {

    /// Publishes the number of elements received from the upstream publisher.
    ///
    /// - Returns: A publisher that consumes all elements until the upstream publisher
    /// finishes, then emits a single value with the total number of elements received.
    public func count() -> Publishers.Count<Self> {
        return Publishers.Count(upstream: self)
    }
}

private final class _Count<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscriber,
      CustomStringConvertible,
      Subscription
    where Downstream.Input == Int,
          Upstream.Failure == Downstream.Failure
{

    typealias Input = Upstream.Output
    typealias Output = Int
    typealias Failure = Downstream.Failure

    private var _count = 0

    var description: String { return "Count" }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
        upstreamSubscription?.request(.unlimited)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        _count += 1
        return .none
    }

    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        if case .finished = completion {
            _ = downstream.receive(_count)
        }
        downstream.receive(completion: completion)
    }

    func request(_ demand: Subscribers.Demand) {
    }
}
