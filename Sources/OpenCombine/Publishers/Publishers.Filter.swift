//
//  Publishers.Filter.swift
//  
//
//  Created by Joseph Spadafora on 7/3/19.
//

import Foundation

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
        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Upstream.Failure == SubscriberType.Failure,
                  Upstream.Output == SubscriberType.Input
        {
            let filter = _Filter<Upstream, SubscriberType>(downstream: subscriber,
                                                           isIncluded: isIncluded)
            upstream.receive(subscriber: filter)
        }
    }

    /// A publisher that republishes all elements that match
    /// a provided error-throwing closure.
    public struct TryFilter<Upstream> : Publisher where Upstream : Publisher {

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
        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Upstream.Output == SubscriberType.Input,
                  SubscriberType.Failure == Failure
        {
            let filter = _Filter<Upstream, SubscriberType>(downstream: subscriber,
                                                           isIncluded: isIncluded)
            upstream.receive(subscriber: filter)
        }
    }
}

extension Publisher {

    /// Republishes all elements that match a provided closure.
    ///
    /// - Parameter isIncluded: A closure that takes one element and returns
    /// a Boolean value indicating whether to republish the element.
    /// - Returns: A publisher that republishes all elements that satisfy the closure.
    public func filter(
        _ isIncluded: @escaping (Self.Output) -> Bool
    ) -> Publishers.Filter<Self> {
        return Publishers.Filter(upstream: self, isIncluded: isIncluded)
    }

    /// Republishes all elements that match a provided error-throwing closure.
    ///
    /// If the `isIncluded` closure throws an error, the publisher fails with that error.
    ///
    /// - Parameter isIncluded:  A closure that takes one element and returns a
    /// Boolean value indicating whether to republish the element.
    /// - Returns:  A publisher that republishes all elements that satisfy the closure.
    public func tryFilter(
        _ isIncluded: @escaping (Self.Output) throws -> Bool
    ) -> Publishers.TryFilter<Self> {
        return Publishers.TryFilter(upstream: self, isIncluded: isIncluded)
    }
}

private final class _Filter<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscriber,
      CustomStringConvertible,
      Subscription
    where Upstream.Output == Downstream.Input
{
    typealias Input = Upstream.Output
    typealias Output = Downstream.Input
    typealias Failure = Upstream.Failure

    private let _isIncluded: (Input) throws -> Bool
    private var _demand: Subscribers.Demand = .none

    init(downstream: Downstream, isIncluded: @escaping (Input) throws -> Bool) {
        self._isIncluded = isIncluded
        super.init(downstream: downstream)
    }

    var description: String { return "Filter" }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        subscription.request(.unlimited)
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        do {
            // input is filtered away, we just return the demand
            if try _isIncluded(input) {
                return downstream.receive(input)
            } else {
                return _demand
            }
        } catch {
            // We can force cast here because the regular filter never fails, so
            downstream.receive(completion: .failure(error as! Downstream.Failure))
            cancel()
            return .none
        }
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .finished:
            downstream.receive(completion: .finished)
        case .failure(let error):
            downstream.receive(completion: .failure(error as! Downstream.Failure))
        }
    }

    func request(_ demand: Subscribers.Demand) {
        _demand = demand
    }
}
