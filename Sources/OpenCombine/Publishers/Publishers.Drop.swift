//
//  Publishers.Drop.swift
//
//
//  Created by Sven Weidauer on 03.10.2019.
//

extension Publisher {
    /// Omits the specified number of elements before republishing subsequent elements.
    ///
    /// - Parameter count: The number of elements to omit.
    /// - Returns: A publisher that does not republish the first `count` elements.
    public func dropFirst(_ count: Int = 1) -> Publishers.Drop<Self> {
        return Publishers.Drop(upstream: self, count: count)
    }
}

extension Publishers {
    /// A publisher that omits a specified number of elements before republishing
    /// later elements.
    public struct Drop<Upstream>: Publisher where Upstream: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The number of elements to drop.
        public let count: Int

        public init(upstream: Upstream, count: Int) {
            self.upstream = upstream
            self.count = count
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Downstream: Subscriber,
                  Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input {
            upstream.subscribe(
                _Drop<Upstream, Downstream>(downstream: subscriber, count: count)
            )
        }
    }
}

private class _Drop<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscription,
      Subscriber
    where Upstream.Output == Downstream.Input,
          Upstream.Failure == Downstream.Failure
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure

    var count: Int

    init(downstream: Downstream, count: Int) {
        self.count = count
        super.init(downstream: downstream)
    }

    func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        guard upstreamSubscription != nil else {
            return .none
        }

        guard count > 0 else {
            return downstream.receive(input)
        }

        count -= 1

        return .max(count)
    }

    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        downstream.receive(completion: completion)
    }
}
