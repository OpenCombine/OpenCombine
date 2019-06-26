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
            let dropWhile = _DropWhile<Upstream, SubscriberType, (Output) -> Bool>(
                downstream: subscriber, predicate: predicate
            )
            upstream.receive(subscriber: dropWhile)
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
            let dropWhile = _DropWhile<Upstream, SubscriberType, (Output) throws -> Bool>(
                downstream: subscriber, predicate: predicate
            )

            upstream.receive(subscriber: dropWhile)
        }
    }
}

private final class _DropWhile<Upstream: Publisher, Downstream: Subscriber, Predicate>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      Subscription
          where Upstream.Output == Downstream.Input
{

    typealias Input = Downstream.Input
    typealias Failure = Upstream.Failure

    private var _downstream: Downstream
    private let _predicate: (Input) throws -> Bool
    private var _predicateReturnedFalse = false
    private var _upstreamSubscription: Subscription?
    private var _demand: Subscribers.Demand = .none

    var description: String { return "DropWhile" }

    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

    init(downstream: Downstream, predicate: @escaping (Input) throws -> Bool) {
        _downstream = downstream
        _predicate = predicate
    }

    func receive(subscription: Subscription) {
        _upstreamSubscription = subscription
        subscription.request(.max(1))
        _downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {

        if _predicateReturnedFalse {
            return _downstream.receive(input)
        }

        do {
            if try !_predicate(input) {
                _predicateReturnedFalse = true
                return _demand + _downstream.receive(input) - 1
            } else {
                return .max(1)
            }
        } catch {
            // Safe to force unwrap here — predicate throws only if we're within
            // a TryDropWhile, and its (and its downstream's) Failure type is always
            // plain Error
            _downstream.receive(completion: .failure(error as! Downstream.Failure))
            cancel()
            return .none
        }
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .finished:
            _downstream.receive(completion: .finished)
        case .failure(let error):
            // Safe to force unwrap here, since Downstream.Failure can be
            // either Upstream.Failure or Error
            _downstream.receive(completion: .failure(error as! Downstream.Failure))
        }
    }

    func request(_ demand: Subscribers.Demand) {
        _demand = demand
    }

    func cancel() {
        _upstreamSubscription?.cancel()
        _upstreamSubscription = nil
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
