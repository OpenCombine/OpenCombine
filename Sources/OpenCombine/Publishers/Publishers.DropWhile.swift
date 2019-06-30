//
//  Publishers.DropWhile.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

extension Publishers {

    /// A publisher that omits elements from an upstream publisher until a given closure
    /// returns false.
    public struct DropWhile<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that indicates whether to drop the element.
        public let predicate: (Output) -> Bool

        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Failure == SubscriberType.Failure, Output == SubscriberType.Input
        {
            let inner = Inner(downstream: subscriber, predicate: catching(predicate))
            upstream.receive(subscriber: inner)
        }
    }

    /// A publisher that omits elements from an upstream publisher until a given
    /// error-throwing closure returns false.
    public struct TryDropWhile<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that indicates whether to drop the element.
        public let predicate: (Upstream.Output) throws -> Bool

        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Output == SubscriberType.Input, SubscriberType.Failure == Error
        {
            let inner = Inner(downstream: subscriber, predicate: catching(predicate))
            upstream.receive(subscriber: inner)
        }
    }
}

private class _DropWhile<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      CustomStringConvertible,
      Subscription
    where Upstream.Output == Downstream.Input
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Predicate = (Input) -> Result<Bool, Downstream.Failure>

    /// The predicate is reset to `nil` as soon as it returns `false`.
    var predicate: Predicate?

    var demand: Subscribers.Demand = .none

    init(downstream: Downstream, predicate: @escaping Predicate) {
        self.predicate = predicate
        super.init(downstream: downstream)
    }

    var description: String { return "DropWhile" }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription

        // NOTE: until the predicate returns false, we will ask the upstream publisher
        // for elements one by one, no matter how much elements the downstream subscriber
        // requests.
        //
        // However, IF the downstream requests anything, we accumulate this demand in the
        // `demand` property so that later we can provide the downstream with the correct
        // amount of values.
        //
        // As soon as the predicate returns false, we switch to the mode where
        // we just forward all the requests from the downstream to the upstream.
        subscription.request(.max(1))

        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {

        guard let predicate = self.predicate else {
            return downstream.receive(input)
        }

        switch predicate(input) {
        case .success(true):
            // See the NOTE above to understand why we return .max(1)
            return .max(1)
        case .success(false):
            // Okay, we hit the first element not satisfying the predicate,
            // from now on we just republish the values to the downstream.
            self.predicate = nil

            // The demand that the downstream has requested has been accumulated in the
            // `demand` property. Now it's time to pay the debt.
            //
            // Subtracting 1 for the current value.
            return demand + downstream.receive(input) - 1
        case .failure(let error):
            downstream.receive(completion: .failure(error))
            cancel()
            return .none
        }
    }

    func request(_ demand: Subscribers.Demand) {
        if predicate == nil {
            // If predicate is nil, that means that we have already received a value
            // that doesn't satisfy the predicate, hence we're in the state where we
            // just forward each request to the upstream.
            upstreamSubscription?.request(demand)
        } else {
            // Otherwise, as mentioned in the NOTE above, we accumulate all the demand
            // requested by the downstream until the predicate returns false.
            self.demand += demand
        }
    }
}

extension Publishers.DropWhile {

    private final class Inner<Downstream: Subscriber>
        : _DropWhile<Upstream, Downstream>,
          Subscriber
        where Upstream.Output == Downstream.Input, Downstream.Failure == Upstream.Failure
    {
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
    }
}

extension Publishers.TryDropWhile {

    private final class Inner<Downstream: Subscriber>
        : _DropWhile<Upstream, Downstream>,
           Subscriber
        where Upstream.Output == Downstream.Input, Downstream.Failure == Error
    {
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion.eraseError())
        }
    }
}

extension Publisher {

    /// Omits elements from the upstream publisher until a given closure returns false,
    /// before republishing all remaining elements.
    ///
    /// - Parameter predicate: A closure that takes an element as a parameter and returns
    ///   a Boolean value indicating whether to drop the element from the publisher’s
    ///   output.
    /// - Returns: A publisher that skips over elements until the provided closure returns
    ///   `false`.
    public func drop(
        while predicate: @escaping (Output) -> Bool
    ) -> Publishers.DropWhile<Self> {
        return Publishers.DropWhile(upstream: self, predicate: predicate)
    }

    /// Omits elements from the upstream publisher until an error-throwing closure returns
    /// false, before republishing all remaining elements.
    ///
    /// If the predicate closure throws, the publisher fails with an error.
    ///
    /// - Parameter predicate: A closure that takes an element as a parameter and returns
    ///   a Boolean value indicating whether to drop the element from the publisher’s
    ///   output.
    /// - Returns: A publisher that skips over elements until the provided closure returns
    ///   `false`, and then republishes all remaining elements. If the predicate closure
    ///   throws, the publisher fails with an error.
    public func tryDrop(
        while predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryDropWhile<Self> {
        return Publishers.TryDropWhile(upstream: self, predicate: predicate)
    }
}
