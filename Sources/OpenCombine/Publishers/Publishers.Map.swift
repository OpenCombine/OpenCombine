//
//  Publishers.Map.swift
//  
//
//  Created by Joseph Spadafora on 6/22/19.
//

extension Publishers {
    
    public struct Map<Upstream, Output>: Publisher where Upstream : Publisher {
        
        public typealias Failure = Upstream.Failure
        
        public let transform: (Upstream.Output) -> Output
        
        public let upstream: Upstream
        
        public init(upstream: Upstream, transform: @escaping (Upstream.Output) -> Output) {
            self.upstream = upstream
            self.transform = transform
        }
        
        public func receive<S: Subscriber>(subscriber: S)
            where Failure == S.Failure, Output == S.Input
        {
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
