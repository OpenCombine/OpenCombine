//
//  Publishers.Decode.swift
//  
//
//  Created by Joseph Spadafora on 6/21/19.
//


extension Publishers {
    
    public struct Decode<Upstream, Output, Coder> : Publisher where Upstream : Publisher, Output : Decodable, Coder : TopLevelDecoder, Upstream.Output == Coder.Input {
        
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error
        
        public let upstream: Upstream
        
        let decoder: Coder
        
        public init(upstream: Upstream, decoder: Coder) {
            self.upstream = upstream
            self.decoder = decoder
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
            let decodeSubscriber = _Decode<Upstream, S, Coder>(downstream: subscriber, decoder: decoder)
            upstream.receive(subscriber: decodeSubscriber)
        }
    }
}

private final class _Decode<Upstream: Publisher, Downstream: Subscriber, Coder: TopLevelDecoder>:
    Subscriber,
    CustomStringConvertible,
    CustomReflectable,
Subscription where Downstream.Input: Decodable, Coder.Input == Upstream.Output, Downstream.Failure == Error {
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Output = Downstream.Input
    
    private let _decoder: Coder
    private var _downstream: Downstream
    private var _upstreamSubscription: Subscription?
    private var _demand: Subscribers.Demand = .none
    
    var description: String { return "Decode" }
    
    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
    
    init(downstream: Downstream, decoder: Coder) {
        self._downstream = downstream
        self._decoder = decoder
    }
    
    func receive(subscription: Subscription) {
        _upstreamSubscription = subscription
        subscription.request(.max(1))
        _downstream.receive(subscription: self)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        do {
            let value = try _decoder.decode(Downstream.Input.self, from: input)
            return _downstream.receive(value)
        } catch {
            _downstream.receive(completion: .failure(error))
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
    public func decode<Item, Coder>(type: Item.Type, decoder: Coder) -> Publishers.Decode<Self, Item, Coder> where Item : Decodable, Coder : TopLevelDecoder, Self.Output == Coder.Input {
        return Publishers.Decode(upstream: self, decoder: decoder)
    }
}
