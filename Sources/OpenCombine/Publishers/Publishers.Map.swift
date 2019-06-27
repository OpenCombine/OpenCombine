//
//  Publishers.Map.swift
//
//
//  Created by Anton Nazarov on 25.06.2019.
//

extension Publisher {

    /// Transforms all elements from the upstream publisher with a provided closure.
    ///
    /// - Parameter transform: A closure that takes one element as its parameter and
    ///   returns a new element.
    /// - Returns: A publisher that uses the provided closure to map elements from
    ///   the upstream publisher to new elements that it then publishes.
    public func map<Result>(
        _ transform: @escaping (Output) -> Result
    ) -> Publishers.Map<Self, Result> {
        return Publishers.Map(upstream: self, transform: transform)
    }

    /// Transforms all elements from the upstream publisher with a provided
    /// error-throwing closure.
    ///
    /// If the `transform` closure throws an error, the publisher fails with the thrown
    /// error.
    ///
    /// - Parameter transform: A closure that takes one element as its parameter and
    ///   returns a new element.
    /// - Returns: A publisher that uses the provided closure to map elements from
    ///   the upstream publisher to new elements that it then publishes.
    public func tryMap<Result>(
        _ transform: @escaping (Self.Output) throws -> Result
    ) -> Publishers.TryMap<Self, Result> {
        return Publishers.TryMap(upstream: self, transform: transform)
    }
}

extension Publishers {
    /// A publisher that transforms all elements from the upstream publisher with
    /// a provided closure.
    public struct Map<Upstream: Publisher, Output> : Publisher {

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that transforms elements from the upstream publisher.
        public let transform: (Upstream.Output) -> Output
    }

    /// A publisher that transforms all elements from the upstream publisher
    /// with a provided error-throwing closure.
    public struct TryMap<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that transforms elements from
        /// the upstream publisher.
        public let transform: (Upstream.Output) throws -> Output
    }
}

extension Publishers.Map {
    public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Output == SubscriberType.Input, SubscriberType.Failure == Upstream.Failure
    {
        let inner = Inner(downstream: subscriber, transform: catching(transform))
        upstream.receive(subscriber: inner)
    }
}

extension Publishers.TryMap {

    public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Output == SubscriberType.Input, SubscriberType.Failure == Error
    {
        let inner = Inner(downstream: subscriber, transform: catching(transform))
        upstream.receive(subscriber: inner)
    }
}

private class _Map<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      CustomStringConvertible,
      Subscription
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Transform = (Input) -> Result<Downstream.Input, Downstream.Failure>

    private let _transform: Transform

    init(downstream: Downstream, transform: @escaping Transform) {
        _transform = transform
        super.init(downstream: downstream)
    }

    var description: String { return "Map" }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        switch _transform(input) {
        case .success(let output):
            return downstream.receive(output)
        case .failure(let error):
            downstream.receive(completion: .failure(error))
            return .none
        }
    }

    func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }

    override func cancel() {
        _upstreamSubscription?.cancel()
    }
}

extension Publishers.Map {

    private final class Inner<Downstream: Subscriber>
        : _Map<Upstream, Downstream>,
          Subscriber
        where Downstream.Failure == Upstream.Failure
    {
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
    }
}

extension Publishers.TryMap {

    private final class Inner<Downstream: Subscriber>
        : _Map<Upstream, Downstream>,
          Subscriber
        where Downstream.Failure == Error
    {
        func receive(completion: Subscribers.Completion<Failure>) {
            // The `completion` argument has the type
            // `Subscribers.Completion<Upstream.Failure>`, and
            // the `downstream.receive(completion:)` method expects
            // `Subscribers.Completion<Error>`.
            //
            // Since user-defined generic types in Swift are invariant relative to their
            // generic parameters, `Subscribers.Completion<Upstream.Failure>` is not
            // a subtype of `Subscribers.Completion<Error>` and therefore cannot be passed
            // where the latter is expected.
            //
            // So we need to destructure `completion` explicitly in this switch.
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case .failure(let error):
                downstream.receive(completion: .failure(error))
            }
        }
    }
}
