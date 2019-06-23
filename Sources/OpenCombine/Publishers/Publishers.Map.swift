//
//  Publishers.Map.swift
//  
//
//  Created by Joseph Spadafora on 6/22/19.
//

extension Publishers {
    
    
    /// A publisher that transforms all elements from the upstream publisher with a provided closure.
    public struct Map<Upstream, Output> : Publisher where Upstream : Publisher {
        
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The closure that transforms elements from the upstream publisher.
        public let transform: (Upstream.Output) -> Output
        
        init(upstream: Upstream, transform: @escaping (Upstream.Output) -> Output) {
            self.upstream = upstream
            self.transform = transform
        }
        
        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where Output == S.Input, S : Subscriber, Upstream.Failure == S.Failure {
            let mapSubscriber = _Map<Upstream, Output, S>(downstream: subscriber, transform: transform)
            upstream.receive(subscriber: mapSubscriber)
        }
    }
}

private final class _Map<Upstream: Publisher, T, Downstream: Subscriber>: Subscriber, CustomStringConvertible, CustomReflectable, Subscription where Downstream.Input == T, Downstream.Failure == Upstream.Failure {
    typealias Failure = Upstream.Failure
    typealias Input = Upstream.Output
    typealias Output = T
    
    private let _transform: (Input) -> T
    private var _downstream: Downstream
    private var _upstreamSubscription: Subscription?
    private var _demand: Subscribers.Demand = .none
    
    init(downstream: Downstream, transform: @escaping (Input) -> T) {
        self._transform = transform
        self._downstream = downstream
    }
    
    var description: String { return "Map" }
    
    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
    
    func receive(subscription: Subscription) {
        _upstreamSubscription = subscription
        subscription.request(.max(1))
        _downstream.receive(subscription: self)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        _downstream.receive(_transform(input))
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .finished:
            _downstream.receive(completion: .finished)
        case .failure(let error):
            _downstream.receive(completion: .failure(error))
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
    public func map<T>(_ transform: @escaping (Output) -> T) -> Publishers.Map<Self, T> {
        return Publishers.Map(upstream: self, transform: transform)
    }
}
