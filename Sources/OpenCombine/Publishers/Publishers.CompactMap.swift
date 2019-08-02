//
//  Publishers.CompactMap.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.07.2019.
//

extension Publishers {

    /// A publisher that republishes all non-`nil` results of calling a closure
    /// with each received element.
    public struct CompactMap<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that receives values from the upstream publisher
        /// and returns optional values.
        public let transform: (Upstream.Output) -> Output?

        public init(upstream: Upstream,
                    transform: @escaping (Upstream.Output) -> Output?) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(downstream: subscriber, transform: catching(transform))
            upstream.subscribe(inner)
        }
    }

    /// A publisher that republishes all non-`nil` results of calling an error-throwing
    /// closure with each received element.
    public struct TryCompactMap<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// An error-throwing closure that receives values from the upstream publisher
        /// and returns optional values.
        ///
        /// If this closure throws an error, the publisher fails.
        public let transform: (Upstream.Output) throws -> Output?

        public init(upstream: Upstream,
                    transform: @escaping (Upstream.Output) throws -> Output?) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(downstream: subscriber, transform: catching(transform))
            upstream.subscribe(inner)
        }
    }
}

extension Publisher {

    /// Calls a closure with each received element and publishes any returned
    /// optional that has a value.
    ///
    /// - Parameter transform: A closure that receives a value and returns
    ///   an optional value.
    /// - Returns: A publisher that republishes all non-`nil` results of calling
    ///   the transform closure.
    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult?
    ) -> Publishers.CompactMap<Self, ElementOfResult> {
        return .init(upstream: self, transform: transform)
    }

    /// Calls an error-throwing closure with each received element and publishes
    /// any returned optional that has a value.
    ///
    /// If the closure throws an error, the publisher cancels the upstream and sends
    /// the thrown error to the downstream receiver as a `Failure`.
    ///
    /// - Parameter transform: an error-throwing closure that receives a value
    ///   and returns an optional value.
    /// - Returns: A publisher that republishes all non-`nil` results of calling
    ///   the `transform` closure.
    public func tryCompactMap<ElementOfResult>(
        _ transform: @escaping (Output) throws -> ElementOfResult?
    ) -> Publishers.TryCompactMap<Self, ElementOfResult> {
        return .init(upstream: self, transform: transform)
    }
}

extension Publishers.CompactMap {

    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult?
    ) -> Publishers.CompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { self.transform($0).flatMap(transform) })
    }

    public func map<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult
    ) -> Publishers.CompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { self.transform($0).map(transform) })
    }
}

extension Publishers.TryCompactMap {

    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) throws -> ElementOfResult?
    ) -> Publishers.TryCompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { try self.transform($0).flatMap(transform) })
    }
}

private class _CompactMap<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscription
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Transform = (Input) -> Result<Downstream.Input?, Downstream.Failure>

    fileprivate var _transform: Transform?

    var _isCompleted: Bool {
        return _transform == nil
    }

    init(downstream: Downstream, transform: @escaping Transform) {
        _transform = transform
        super.init(downstream: downstream)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        guard let transform = _transform else { return .none }

        switch transform(input) {
        case .success(let output?):
            return downstream.receive(output)
        case .success(nil):
            return .max(1)
        case .failure(let error):
            downstream.receive(completion: .failure(error))
            _transform = nil
            return .none
        }
    }

    func request(_ demand: Subscribers.Demand) {
        guard !_isCompleted else { return }
        upstreamSubscription?.request(demand)
    }

    override func cancel() {
        _transform = nil
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
    }
}

extension Publishers.CompactMap {
    private final class Inner<Downstream: Subscriber>
        : _CompactMap<Upstream, Downstream>,
          Subscriber,
          CustomStringConvertible
        where Downstream.Failure == Upstream.Failure
    {
        var description: String { return "CompactMap" }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            if !_isCompleted {
                _transform = nil
                downstream.receive(completion: completion)
            }
        }
    }
}

extension Publishers.TryCompactMap {
    private final class Inner<Downstream: Subscriber>
        : _CompactMap<Upstream, Downstream>,
          Subscriber,
          CustomStringConvertible
        where Downstream.Failure == Error
    {
        var description: String { return "TryCompactMap" }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            if !_isCompleted {
                _transform = nil
                downstream.receive(completion: completion.eraseError())
            }
        }
    }
}
