//
//  File.swift
//  
//
//  Created by Joseph Spadafora on 7/8/19.
//

import Foundation

extension Publishers {

    /// A publisher that publishes the first element of a stream, then finishes.
    public struct First<Upstream: Publisher>:Publisher {

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
        /// - subscriber: The subscriber to attach to this `Publisher`.
        ///   once attached it can begin to receive values.
        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Failure == SubscriberType.Failure,
                  Output == SubscriberType.Input
        {
            let firstSubscriber = _First<Upstream, SubscriberType>(downstream: subscriber)
            upstream.receive(subscriber: firstSubscriber)
        }
    }

    /// A publisher that only publishes the first element of a
    /// stream to satisfy a predicate closure.
    public struct FirstWhere<Upstream: Publisher>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that determines whether to publish an element.
        public let predicate: (Output) -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Failure == SubscriberType.Failure,
                  Output == SubscriberType.Input
        {
            let firstWhereSubscriber = _FirstWhere<Upstream, SubscriberType>(
                downstream: subscriber,
                isIncluded: predicate
            )
            upstream.receive(subscriber: firstWhereSubscriber)
        }
    }

    /// A publisher that only publishes the first element of a stream
    /// to satisfy a throwing predicate closure.
    public struct TryFirstWhere<Upstream: Publisher>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that determines whether to publish an element.
        public let predicate: (Output) throws -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Failure == SubscriberType.Failure,
                  Output == SubscriberType.Input
        {
            let tryFirstWhere = _TryFirstWhere<Upstream, SubscriberType>(
                downstream: subscriber,
                isIncluded: predicate
            )
            upstream.receive(subscriber: tryFirstWhere)
        }
    }
}

// MARK: - Inner Classes
private class _First<Upstream: Publisher, Downstream: Subscriber>
    : _FirstWhereBase<Upstream, Downstream>,
      CustomStringConvertible
    where Upstream.Output == Downstream.Input,
          Upstream.Failure == Downstream.Failure
{
    var description: String { return "First" }

    init(downstream: Downstream) {
        super.init(downstream: downstream,
                   predicate: { _ in .success(true) },
                   errorConversion: { $0 }
        )
    }
}

private class _FirstWhere<Upstream: Publisher, Downstream: Subscriber>
    : _FirstWhereBase<Upstream, Downstream>,
      CustomStringConvertible
    where Upstream.Output == Downstream.Input,
          Upstream.Failure == Downstream.Failure
{
    var description: String { return "TryFirst" }

    init(downstream: Downstream, isIncluded: @escaping (Upstream.Output) -> Bool) {
        super.init(downstream: downstream,
                   predicate: { .success(isIncluded($0)) },
                   errorConversion: { $0 })
    }
}

private class _TryFirstWhere<Upstream: Publisher, Downstream: Subscriber>
    : _FirstWhereBase<Upstream, Downstream>,
      CustomStringConvertible
    where Upstream.Output == Downstream.Input,
          Downstream.Failure == Error
{
    typealias Input = Upstream.Output
    typealias Output = Input

    var description: String { return "TryFirstWhere" }

    init(downstream: Downstream, isIncluded: @escaping (Input) throws -> Bool) {
        super.init(downstream: downstream,
                   predicate: { input in Result { try isIncluded(input) } },
                   errorConversion: { $0 as Error }
        )
    }
}

private class _FirstWhereBase<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscription,
      Subscriber
    where Downstream.Input == Upstream.Output
{

    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Predicate = (Input) -> Result<Bool, Downstream.Failure>

    var predicate: Predicate
    var isActive = true
    var first: Input?

    let _errorConversion: (Upstream.Failure) -> Downstream.Failure

    init(downstream: Downstream,
         predicate: @escaping Predicate,
         errorConversion: @escaping (Upstream.Failure) -> Downstream.Failure) {
        self.predicate = predicate
        self._errorConversion = errorConversion
        super.init(downstream: downstream)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        guard isActive else { return .none }
        switch predicate(input) {
        case .success(let isMatch):
            if isMatch {
                _ = downstream.receive(input)
                downstream.receive(completion: .finished)
                isActive = false
            }
        case .failure(let error):
            downstream.receive(completion: .failure(error))
            cancel()
        }
        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        guard isActive else { return }
        switch completion {
        case .failure(let upstreamError):
            let converted = _errorConversion(upstreamError)
            downstream.receive(completion: .failure(converted))
        case .finished:
            downstream.receive(completion: .finished)
        }
        isActive = false
    }

    func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(.unlimited)
    }
}

// MARK: - Publisher extensions
extension Publisher {

    /// Publishes the first element of a stream, then finishes.
    ///
    /// If this publisher doesn’t receive any elements, it finishes without publishing.
    /// - Returns: A publisher that only publishes the first element of a stream.
    public func first() -> Publishers.First<Self> {
        return Publishers.First(upstream: self)
    }

    /// Publishes the first element of a stream to
    /// satisfy a predicate closure, then finishes.
    ///
    /// The publisher ignores all elements after the first.
    /// If this publisher doesn’t receive any elements,
    /// it finishes without publishing.
    /// - Parameter predicate: A closure that takes an element as a parameter and
    /// returns a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the first element of a stream
    /// that satifies the predicate.
    public func first(where predicate: @escaping (Output) -> Bool)
        -> Publishers.FirstWhere<Self>
    {
        return Publishers.FirstWhere(upstream: self, predicate: predicate)
    }

    /// Publishes the first element of a stream to satisfy a
    /// throwing predicate closure, then finishes.
    ///
    /// The publisher ignores all elements after the first. If this publisher
    /// doesn’t receive any elements, it finishes without publishing. If the
    /// predicate closure throws, the publisher fails with an error.
    /// - Parameter predicate: A closure that takes an element as a parameter and
    /// returns a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the first element of a stream
    /// that satifies the predicate.
    public func tryFirst(
        where predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFirstWhere<Self>
    {
        return Publishers.TryFirstWhere(upstream: self, predicate: predicate)
    }
}
