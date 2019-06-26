//
//  Publishers.Filter.swift
//  
//
//  Created by Joseph Spadafora on 6/25/19.
//

import Foundation


extension Publishers {
    
    /// A publisher that republishes all elements that match a provided closure.
    public struct Filter<Upstream> : Publisher where Upstream : Publisher {
        
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
        
        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Failure == S.Failure, Upstream.Output == S.Input {
            let filter = _Filter<Upstream, S>(downstream: subscriber, isIncluded: isIncluded)
            upstream.receive(subscriber: filter)
        }
    }
    
    /// A publisher that republishes all elements that match a provided error-throwing closure.
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
        
        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Output == S.Input, S.Failure == Publishers.TryFilter<Upstream>.Failure {
            let filter = _Filter<Upstream, S>(downstream: subscriber, isIncluded: isIncluded)
            upstream.receive(subscriber: filter)
        }
    }
}

private final class _Filter<Upstream: Publisher, Downstream: Subscriber>:  Subscriber,
    CustomStringConvertible,
    CustomReflectable,
Subscription where Upstream.Output == Downstream.Input {
    typealias Input = Upstream.Output
    typealias Output = Downstream.Input
    typealias Failure = Upstream.Failure
    
    private var _downstream: Downstream
    private let _isIncluded: (Input) throws -> Bool
    private var _upstreamSubscription: Subscription?
    private var _demand: Subscribers.Demand = .none
    
    init(downstream: Downstream, isIncluded: @escaping (Input) throws -> Bool) {
        self._isIncluded = isIncluded
        self._downstream = downstream
    }
    
    
    var description: String { return "Filter" }
    
    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
    
    func receive(subscription: Subscription) {
        _upstreamSubscription = subscription
        subscription.request(.unlimited)
        _downstream.receive(subscription: self)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        do {
            // input is filtered away, we just return the demand
            if try _isIncluded(input) {
                return _downstream.receive(input)
            } else {
                return _demand
            }
        } catch {
            // We can force cast here because the regular filter never fails, so
            _downstream.receive(completion: .failure(error as! Downstream.Failure))
            cancel()
            return .none
        }
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .finished: _downstream.receive(completion: .finished)
        case .failure(let error): _downstream.receive(completion: .failure(error as! Downstream.Failure))
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

extension Publishers.Filter {
    public func filter(_ isIncluded: @escaping (Publishers.Filter<Upstream>.Output) -> Bool) -> Publishers.Filter<Upstream> {
        return Publishers.Filter(upstream: upstream) { isIncluded($0) && self.isIncluded($0) }
    }
    
    public func tryFilter(_ isIncluded: @escaping (Publishers.Filter<Upstream>.Output) throws -> Bool) -> Publishers.TryFilter<Upstream> {
        return Publishers.TryFilter(upstream: upstream) { try isIncluded($0) && self.isIncluded($0) }
    }
}

extension Publishers.TryFilter {

    public func filter(_ isIncluded: @escaping (Publishers.TryFilter<Upstream>.Output) -> Bool) -> Publishers.TryFilter<Upstream> {
        return Publishers.TryFilter(upstream: upstream)  { try isIncluded($0) && self.isIncluded($0) }
    }

    public func tryFilter(_ isIncluded: @escaping (Publishers.TryFilter<Upstream>.Output) throws -> Bool) -> Publishers.TryFilter<Upstream> {
        return Publishers.TryFilter(upstream: upstream) { try isIncluded($0) && self.isIncluded($0) }
    }
}
