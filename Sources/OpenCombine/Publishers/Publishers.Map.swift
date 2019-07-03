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
    /// - Returns: A publisher that uses the provided closure to map elements from the
    ///   upstream publisher to new elements that it then publishes.
    public func map<Result>(_ transform: @escaping (Output) -> Result)
        -> Publishers.Map<Self, Result> {
            return Publishers.Map(upstream: self, transform: transform)
    }
}

extension Publishers {
    /// A publisher that transforms all elements from the upstream publisher with
    /// a provided closure.
    public struct Map<Upstream: Publisher, Output> : Publisher {

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that transforms elements from the upstream publisher.
        public let transform: (Upstream.Output) -> Output
    }
}

extension Publishers.Map {
    public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Output == SubscriberType.Input,
        Upstream.Failure == SubscriberType.Failure {
            let inner = Inner<Upstream, SubscriberType>(
                downstream: subscriber, transform: transform
            )
            upstream.receive(subscriber: inner)
    }
}

private final class Inner<Upstream: Publisher, Downstream: Subscriber>
    : Subscriber,
      Subscription {
    typealias Input = Upstream.Output
    typealias Failure = Downstream.Failure
    typealias Transform = (Input) -> Downstream.Input

    private let _downstream: Downstream
    private var _upstreamSubscription: Subscription?
    private let _transform: Transform

    init(downstream: Downstream, transform: @escaping Transform) {
        _downstream = downstream
        _transform = transform
    }

    func receive(subscription: Subscription) {
        _upstreamSubscription = subscription
        _downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        return _downstream.receive(_transform(input))
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        _downstream.receive(completion: completion)
    }

    func request(_ demand: Subscribers.Demand) {
        _upstreamSubscription?.request(demand)
    }

    func cancel() {
        _upstreamSubscription?.cancel()
    }
}

// MARK: - CustomStringConvertible
extension Inner: CustomStringConvertible {
    public var description: String { return "Map" }
}

// MARK: - CustomReflectable
extension Inner: CustomReflectable {
    public var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
}
