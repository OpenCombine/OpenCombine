//
//  Publishers.Encode.swift
//
//
//  Created by Joseph Spadafora on 6/22/19.
//

extension Publishers {

    public struct Encode<Upstream, Coder>: Publisher
        where Upstream: Publisher,
              Coder: TopLevelEncoder,
              Upstream.Output: Encodable
    {

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

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            let encodeSubscriber = _Encode<Upstream, Downstream, Coder>(
                downstream: subscriber,
                encoder: encoder
            )
            upstream.subscribe(encodeSubscriber)
        }
    }
}

private final class _Encode<Upstream: Publisher,
                            Downstream: Subscriber,
                            Coder: TopLevelEncoder>
    : OperatorSubscription<Downstream>,
      Subscriber,
      CustomStringConvertible,
      Subscription
    where Coder.Output == Downstream.Input,
          Upstream.Output: Encodable,
          Downstream.Failure == Error {

    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Output = Downstream.Input

    private let _encoder: Coder

    var description: String { return "Encode" }

    init(downstream: Downstream, encoder: Coder) {
        self._encoder = encoder
        super.init(downstream: downstream)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        do {
            let value = try _encoder.encode(input)
            return downstream.receive(value)
        } catch {
            downstream.receive(completion: .failure(error))
            cancel()
            return .none
        }
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        downstream.receive(completion: completion.eraseError())
    }

    func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }
}

extension Publisher {
    public func encode<Coder>(
        encoder: Coder
    ) -> Publishers.Encode<Self, Coder>
        where Coder: TopLevelEncoder
    {
        return Publishers.Encode(upstream: self, encoder: encoder)
    }
}
