//
//  Publishers.Decode.swift
//
//
//  Created by Joseph Spadafora on 6/21/19.
//

extension Publishers {

    public struct Decode<Upstream, Output, Coder> : Publisher where
        Upstream : Publisher,
        Output : Decodable,
        Coder : TopLevelDecoder,
        Upstream.Output == Coder.Input {

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error

        public let upstream: Upstream

        internal let decoder: Coder

        public init(upstream: Upstream, decoder: Coder) {
            self.upstream = upstream
            self.decoder = decoder
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Receiver: Subscriber>(subscriber: Receiver)
            where Failure == Receiver.Failure, Output == Receiver.Input {
                let decodeSubscriber = _Decode<Upstream, Receiver, Coder>(
                    downstream: subscriber,
                    decoder: decoder
                )
                upstream.receive(subscriber: decodeSubscriber)
        }
    }
}

// swiftlint:disable:next line_length
private final class _Decode<Upstream: Publisher, Downstream: Subscriber, Coder: TopLevelDecoder>:
    OperatorSubscription<Downstream>, Subscriber,
    CustomStringConvertible, Subscription
    where
    Downstream.Input: Decodable,
    Coder.Input == Upstream.Output,
    Downstream.Failure == Error {

    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Output = Downstream.Input

    private let _decoder: Coder
    private var _demand: Subscribers.Demand = .none

    var description: String { return "Decode" }

    init(downstream: Downstream, decoder: Coder) {
        self._decoder = decoder
        super.init(downstream: downstream)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        subscription.request(.unlimited)
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        do {
            let value = try _decoder.decode(Downstream.Input.self, from: input)
            return downstream.receive(value)
        } catch {
            downstream.receive(completion: .failure(error))
            cancel()
            return .none
        }
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .finished:
            downstream.receive(completion: .finished)
        case .failure(let error):
            downstream.receive(completion: .failure(error))
        }
    }

    func request(_ demand: Subscribers.Demand) {
        _demand = demand
    }
}

extension Publisher {
    public func decode<Item, Coder>(type: Item.Type, decoder: Coder)
        -> Publishers.Decode<Self, Item, Coder>
        where Item : Decodable, Coder : TopLevelDecoder, Self.Output == Coder.Input {
            return Publishers.Decode(upstream: self, decoder: decoder)
    }
}
