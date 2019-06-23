//
//  Publishers.Encode.swift
//  
//
//  Created by Joseph Spadafora on 6/22/19.
//


extension Publishers {
    
    public struct Encode<Upstream, Coder> : Publisher where Upstream : Publisher, Coder : TopLevelEncoder, Upstream.Output : Encodable {
        
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error
        
        /// The kind of values published by this publisher.
        public typealias Output = Coder.Output
        
        public let upstream: Upstream
        
        private let encoder: Coder
        
        public init(upstream: Upstream, encoder: Coder) {
            self.upstream = upstream
            self.encoder = encoder
        }
        
        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S: Subscriber>(subscriber: S)
            where Failure == S.Failure, Output == S.Input
        {
            let encodeSubscriber = _Encode<Upstream, S, Coder>(downstream: subscriber, encoder: encoder)
            upstream.receive(subscriber: encodeSubscriber)
        }
    }
}

private final class _Encode<Upstream: Publisher, Downstream: Subscriber, Coder: TopLevelEncoder>:
    Subscriber,
    CustomStringConvertible,
    CustomReflectable,
Subscription where Coder.Output == Downstream.Input, Upstream.Output: Encodable {
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Output = Downstream.Input
    
    private let _encoder: Coder
    private var _downstream: Downstream
    private var _upstreamSubscription: Subscription?
    private var _demand: Subscribers.Demand = .none
    
    var description: String { return "Encode" }
    
    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
    
    init(downstream: Downstream, encoder: Coder) {
        self._downstream = downstream
        self._encoder = encoder
    }
    
    func receive(subscription: Subscription) {
        _upstreamSubscription = subscription
        subscription.request(.max(1))
        _downstream.receive(subscription: self)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        do {
            let value = try _encoder.encode(input)
            return _downstream.receive(value)
        } catch {
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
    public func encode<Coder>(encoder: Coder) -> Publishers.Encode<Self, Coder> where Coder : TopLevelEncoder {
        return Publishers.Encode(upstream: self, encoder: encoder)
    }
}


