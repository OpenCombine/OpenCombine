//
//  Publishers.Comparison.swift
//  OpenCombine
//
//  Created by Ilija Puaca on 22/7/19.
//

extension Publishers {

    /// A publisher that republishes items from another publisher only if each new item is
    /// in increasing order from the previously-published item.
    public struct Comparison<Upstream>: Publisher where Upstream: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that receives two elements and returns `true` if they are in
        /// increasing order.
        public let areInIncreasingOrder: (Upstream.Output, Upstream.Output) -> Bool

        public init(
            upstream: Upstream,
            areInIncreasingOrder: @escaping (Upstream.Output, Upstream.Output) -> Bool) {
            self.upstream = upstream
            self.areInIncreasingOrder = areInIncreasingOrder
        }

        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Downstream: Subscriber,
            Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input {
            let sub = Inner<Upstream, Downstream>(
                downstream: subscriber,
                areInIncreasingOrder: catching2(areInIncreasingOrder))
            upstream.subscribe(sub)
        }
    }

    /// A publisher that republishes items from another publisher only if each new item is
    /// in increasing order from the previously-published item, and fails if the ordering
    /// logic throws an error.
    public struct TryComparison<Upstream>: Publisher where Upstream: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that receives two elements and returns `true` if they are in
        /// increasing order.
        public let areInIncreasingOrder: (Upstream.Output, Upstream.Output) throws -> Bool

        public init(upstream: Upstream,
                    areInIncreasingOrder:
            @escaping (Upstream.Output, Upstream.Output) throws -> Bool) {
            self.upstream = upstream
            self.areInIncreasingOrder = areInIncreasingOrder
        }

        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Downstream: Subscriber,
            Upstream.Output == Downstream.Input,
            Downstream.Failure == Publishers.TryComparison<Upstream>.Failure {
            let sub = Inner<Upstream, Downstream>(
                downstream: subscriber,
                areInIncreasingOrder: catching2(areInIncreasingOrder))
            upstream.subscribe(sub)
        }
    }
}

extension Publisher where Self.Output : Comparable {

    /// Publishes the minimum value received from the upstream publisher, after it
    /// finishes.
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    /// - Returns: A publisher that publishes the minimum value received from the upstream
    /// publisher, after the upstream publisher finishes.
    public func min() -> Publishers.Comparison<Self> {
        return Publishers.Comparison(upstream: self, areInIncreasingOrder: <)
    }

    /// Publishes the maximum value received from the upstream publisher, after it
    /// finishes.
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    /// - Returns: A publisher that publishes the maximum value received from the upstream
    /// publisher, after the upstream publisher finishes.
    public func max() -> Publishers.Comparison<Self> {
        return Publishers.Comparison(upstream: self, areInIncreasingOrder: >)
    }
}

extension Publisher {

    /// Publishes the minimum value received from the upstream publisher, after it
    /// finishes.
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    /// - Parameter areInIncreasingOrder: A closure that receives two elements and returns
    /// `true` if they are in increasing order.
    /// - Returns: A publisher that publishes the minimum value received from the upstream
    /// publisher, after the upstream publisher finishes.
    public func min(by areInIncreasingOrder:
        @escaping (Self.Output, Self.Output) -> Bool) -> Publishers.Comparison<Self> {
        return Publishers.Comparison(upstream: self,
                                     areInIncreasingOrder: areInIncreasingOrder)
    }

    /// Publishes the minimum value received from the upstream publisher, using the
    /// provided error-throwing closure to order the items.
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    /// - Parameter areInIncreasingOrder: A throwing closure that receives two elements
    /// and returns `true` if they are in increasing order. If this closure throws, the
    /// publisher terminates with a `Failure`.
    /// - Returns: A publisher that publishes the minimum value received from the upstream
    /// publisher, after the upstream publisher finishes.
    public func tryMin(by areInIncreasingOrder:
        @escaping (Self.Output, Self.Output) throws -> Bool)
        -> Publishers.TryComparison<Self> {
        return Publishers.TryComparison(upstream: self,
                                        areInIncreasingOrder: areInIncreasingOrder)
    }

    /// Publishes the maximum value received from the upstream publisher, using the
    /// provided ordering closure.
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    /// - Parameter areInIncreasingOrder: A closure that receives two elements and returns
    /// `true` if they are in increasing order.
    /// - Returns: A publisher that publishes the maximum value received from the upstream
    /// publisher, after the upstream publisher finishes.
    public func max(by areInIncreasingOrder:
        @escaping (Self.Output, Self.Output) -> Bool) -> Publishers.Comparison<Self> {
        return Publishers.Comparison(upstream: self,
                                     areInIncreasingOrder: areInIncreasingOrder)
    }

    /// Publishes the maximum value received from the upstream publisher, using the
    /// provided error-throwing closure to order the items.
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    /// - Parameter areInIncreasingOrder: A throwing closure that receives two elements
    /// and returns `true` if they are in increasing order. If this closure throws, the
    /// publisher terminates with a `Failure`.
    /// - Returns: A publisher that publishes the maximum value received from the upstream
    /// publisher, after the upstream publisher finishes.
    public func tryMax(by areInIncreasingOrder:
        @escaping (Self.Output, Self.Output) throws -> Bool)
        -> Publishers.TryComparison<Self> {
        return Publishers.TryComparison(upstream: self,
                                        areInIncreasingOrder: areInIncreasingOrder)
    }
}

private class _Comparison<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>, Subscription
    where Upstream.Output == Downstream.Input {

    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Comparison = (Input, Input) -> Result<Bool, Downstream.Failure>

    var currentValue: Input?
    var isCompleted: Bool { areInIncreasingOrder == nil }

    private var areInIncreasingOrder: Comparison?

    // MARK: - Lifecycle

    init(downstream: Downstream, areInIncreasingOrder: @escaping Comparison) {
        self.areInIncreasingOrder = areInIncreasingOrder
        super.init(downstream: downstream)
    }

    // MARK: - OperatorSubscription

    override func cancel() {
        areInIncreasingOrder = nil
        super.cancel()
    }

    // MARK: - Subscriber

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
        upstreamSubscription?.request(.unlimited)
    }

    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        guard !isCompleted, let areInIncreasingOrder = self.areInIncreasingOrder else {
            return .none
        }

        guard let current = currentValue else {
            currentValue = input
            return .none
        }

        switch areInIncreasingOrder(current, input) {
        case .success(let isIncreasing):
            currentValue = isIncreasing ? current : input
        case .failure(let error):
            downstream.receive(completion: .failure(error))
            cancel()
        }

        return .none
    }

    // MARK: - Subscription

    func request(_ demand: Subscribers.Demand) {}
}

extension Publishers.Comparison {

    private final class Inner<Upstream: Publisher, Downstream: Subscriber>
        : _Comparison<Upstream, Downstream>, Subscriber, CustomStringConvertible
        where Upstream.Output == Downstream.Input,
              Downstream.Failure == Upstream.Failure {

        // MARK: - CustomStringConvertible

        var description: String { "Comparison" }

        // MARK: - Subscriber

        func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            guard !isCompleted else { return }

            switch completion {
            case .finished:
                guard let value = currentValue else { break }
                _ = downstream.receive(value)
            case .failure:
                cancel()
            }

            downstream.receive(completion: completion)
        }
    }
}

extension Publishers.TryComparison {

    private final class Inner<Upstream: Publisher, Downstream: Subscriber>
        : _Comparison<Upstream, Downstream>, Subscriber, CustomStringConvertible
        where Upstream.Output == Downstream.Input, Downstream.Failure == Error {

        // MARK: - CustomStringConvertible

        var description: String { "TryComparison" }

        // MARK: - Subscriber

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            guard !isCompleted else { return }

            switch completion {
            case .finished:
                guard let value = currentValue else { break }
                _ = downstream.receive(value)
            case .failure:
                cancel()
            }

            downstream.receive(completion: completion.eraseError())
        }
    }
}
