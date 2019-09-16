//
//  Publishers.Filter.swift
//  
//
//  Created by Joseph Spadafora on 7/3/19.
//

extension Publisher {

    /// Republishes all elements that match a provided closure.
    ///
    /// - Parameter isIncluded: A closure that takes one element and returns
    ///   a Boolean value indicating whether to republish the element.
    /// - Returns: A publisher that republishes all elements that satisfy the closure.
    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.Filter<Self> {
        return Publishers.Filter(upstream: self, isIncluded: isIncluded)
    }

    /// Republishes all elements that match a provided error-throwing closure.
    ///
    /// If the `isIncluded` closure throws an error, the publisher fails with that error.
    ///
    /// - Parameter isIncluded:  A closure that takes one element and returns a
    ///   Boolean value indicating whether to republish the element.
    /// - Returns:  A publisher that republishes all elements that satisfy the closure.
    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Self> {
        return Publishers.TryFilter(upstream: self, isIncluded: isIncluded)
    }
}

extension Publishers.Filter {

    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.Filter<Upstream> {
        return .init(upstream: upstream) { self.isIncluded($0) && isIncluded($0) }
    }

    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }
}

extension Publishers.TryFilter {

    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }

    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }
}

extension Publishers {

    /// A publisher that republishes all elements that match a provided closure.
    public struct Filter<Upstream: Publisher>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that indicates whether to republish an element.
        public let isIncluded: (Upstream.Output) -> Bool

        public init(upstream: Upstream, isIncluded: @escaping (Output) -> Bool) {
            self.upstream = upstream
            self.isIncluded = isIncluded
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
                  Upstream.Output == Downstream.Input
        {
            let filter = Inner(downstream: subscriber, isIncluded: catching(isIncluded))
            upstream.receive(subscriber: filter)
        }
    }

    /// A publisher that republishes all elements that match
    /// a provided error-throwing closure.
    public struct TryFilter<Upstream>: Publisher where Upstream: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A error-throwing closure that indicates whether to republish an element.
        public let isIncluded: (Upstream.Output) throws -> Bool

        public init(upstream: Upstream,
                    isIncluded: @escaping (Upstream.Output) throws -> Bool) {
            self.upstream = upstream
            self.isIncluded = isIncluded
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Output == Downstream.Input,
                  Downstream.Failure == Failure
        {
            let filter = Inner(downstream: subscriber, isIncluded: catching(isIncluded))
            upstream.receive(subscriber: filter)
        }
    }
}

private class _Filter<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscription
    where Upstream.Output == Downstream.Input
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Predicate = (Input) -> Result<Bool, Downstream.Failure>

    private var _isIncluded: Predicate?

    var isFinished: Bool {
        return _isIncluded == nil
    }

    init(downstream: Downstream, isIncluded: @escaping Predicate) {
        _isIncluded = isIncluded
        super.init(downstream: downstream)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        guard let isIncluded = _isIncluded else { return .none }
        switch isIncluded(input) {
        case .success(let isIncluded):
            return isIncluded ? downstream.receive(input) : .max(1)
        case .failure(let error):
            downstream.receive(completion: .failure(error))
            cancel()
            return .none
        }
    }

    func request(_ demand: Subscribers.Demand) {
        guard !isFinished else { return }
        upstreamSubscription?.request(demand)
    }

    override func cancel() {
        _isIncluded = nil
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
    }
}

extension Publishers.Filter {

    private final class Inner<Downstream: Subscriber>
        : _Filter<Upstream, Downstream>,
          Subscriber,
          CustomStringConvertible
        where Upstream.Output == Downstream.Input,
              Upstream.Failure == Downstream.Failure {

        var description: String { return "Filter" }

        func receive(completion: Subscribers.Completion<Failure>) {
            guard !isFinished else { return }
            downstream.receive(completion: completion)
        }
    }
}

extension Publishers.TryFilter {

    private final class Inner<Downstream: Subscriber>
        : _Filter<Upstream, Downstream>,
          Subscriber,
          CustomStringConvertible
        where Upstream.Output == Downstream.Input, Downstream.Failure == Error {

        var description: String { return "TryFilter" }

        func receive(completion: Subscribers.Completion<Failure>) {
            guard !isFinished else { return }
            downstream.receive(completion: completion.eraseError())
        }
    }
}
