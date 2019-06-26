//
//  Publishers.Count.swift
//  
//
//  Created by Joseph Spadafora on 6/25/19.
//

import Foundation

extension Publishers {
    
    /// A publisher that publishes the number of elements received from the upstream publisher.
    public struct Count<Upstream> : Publisher where Upstream : Publisher {
        
        /// The kind of values published by this publisher.
        public typealias Output = Int
        
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Failure == S.Failure, S.Input == Publishers.Count<Upstream>.Output {
            let count = _Count<Upstream, S>(downstream: subscriber)
            upstream.receive(subscriber: count)
        }
    }
}

private final class _Count<Upstream: Publisher, Downstream: Subscriber>: Subscriber, CustomStringConvertible, CustomReflectable, Subscription where Downstream.Input == Int, Upstream.Failure == Downstream.Failure {
    
    typealias Input = Upstream.Output
    typealias Output = Int
    typealias Failure = Downstream.Failure
    
    private var _downstream: Downstream
    private var _upstreamSubscription: Subscription?
    private var _demand: Subscribers.Demand = .none
    
    private var _count = 0
    
    var description: String { return "Count" }
    
    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

    
    init(downstream: Downstream) {
        self._downstream = downstream
    }
    
    func receive(subscription: Subscription) {
        _upstreamSubscription = subscription
        subscription.request(.unlimited)
        _downstream.receive(subscription: self)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        _count += 1
        return _demand
    }
    
    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        if case .finished = completion {
            _demand = _downstream.receive(_count)
        }
        _downstream.receive(completion: completion)
    }
    
    func request(_ demand: Subscribers.Demand) {
        _demand = demand
    }
    
    func cancel() {
        _upstreamSubscription?.cancel()
        _upstreamSubscription = nil
    }
}
