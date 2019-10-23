// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃                                                                                     ┃
// ┃                   Auto-generated from GYB template. DO NOT EDIT!                    ┃
// ┃                                                                                     ┃
// ┃                                                                                     ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//
//  Publishers.Encode.swift.gyb
//
//
//  Created by Joseph Spadafora on 6/22/19.
//

extension Publisher {

    /// Encodes the output from upstream using a specified `TopLevelEncoder`.
    /// For example, use `JSONEncoder`.
    public func encode<Coder: TopLevelEncoder>(
        encoder: Coder
    ) -> Publishers.Encode<Self, Coder> {
        return .init(upstream: self, encoder: encoder)
    }

    /// Decodes the output from upstream using a specified `TopLevelDecoder`.
    /// For example, use `JSONDecoder`.
    public func decode<Item: Decodable, Coder: TopLevelDecoder>(
        type: Item.Type,
        decoder: Coder
    ) -> Publishers.Decode<Self, Item, Coder> where Output == Coder.Input {
        return .init(upstream: self, decoder: decoder)
    }
}

extension Publishers {

    public struct Encode<Upstream: Publisher, Coder: TopLevelEncoder>: Publisher
        where Upstream.Output: Encodable
    {
        public typealias Failure = Error

        public typealias Output = Coder.Output

        public let upstream: Upstream

        private let _encode: (Upstream.Output) throws -> Output

        public init(upstream: Upstream, encoder: Coder) {
            self.upstream = upstream
            self._encode = encoder.encode
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, encode: _encode))
        }
    }

    public struct Decode<Upstream: Publisher, Output: Decodable, Coder: TopLevelDecoder>
        : Publisher
        where Upstream.Output == Coder.Input
    {
        public typealias Failure = Error

        public let upstream: Upstream

        private let _decode: (Upstream.Output) throws -> Output

        public init(upstream: Upstream, decoder: Coder) {
            self.upstream = upstream
            self._decode = { try decoder.decode(Output.self, from: $0) }
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, decode: _decode))
        }
    }
}

extension Publishers.Encode {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Error
    {
        // NOTE: This class has been audited for thread safety.
        // Combine doesn't use any locking here.

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let encode: (Upstream.Output) throws -> Output

        private var finished = false

        private var subscription: Subscription?

        fileprivate init(
            downstream: Downstream,
            encode: @escaping (Upstream.Output) throws -> Output
        ) {
            self.downstream = downstream
            self.encode = encode
        }

        func receive(subscription: Subscription) {
            if finished || self.subscription != nil {
                subscription.cancel()
                return
            }
            self.subscription = subscription
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            if finished { return .none }
            do {
                return try downstream.receive(encode(input))
            } catch {
                finished = true
                subscription?.cancel()
                subscription = nil
                downstream.receive(completion: .failure(error))
                return .none
            }
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            if finished { return }
            finished = true
            subscription = nil
            downstream.receive(completion: completion.eraseError())
        }

        func request(_ demand: Subscribers.Demand) {
            subscription?.request(demand)
        }

        func cancel() {
            guard let subscription = self.subscription, !finished else { return }
            subscription.cancel()
            self.subscription = nil
            finished = true
        }

        var description: String { return "Encode" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("finished", finished),
                ("upstreamSubscription", subscription as Any)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.Decode {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Error
    {
        // NOTE: This class has been audited for thread safety.
        // Combine doesn't use any locking here.

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let decode: (Upstream.Output) throws -> Output

        private var finished = false

        private var subscription: Subscription?

        fileprivate init(
            downstream: Downstream,
            decode: @escaping (Upstream.Output) throws -> Output
        ) {
            self.downstream = downstream
            self.decode = decode
        }

        func receive(subscription: Subscription) {
            if finished || self.subscription != nil {
                subscription.cancel()
                return
            }
            self.subscription = subscription
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            if finished { return .none }
            do {
                return try downstream.receive(decode(input))
            } catch {
                finished = true
                subscription?.cancel()
                subscription = nil
                downstream.receive(completion: .failure(error))
                return .none
            }
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            if finished { return }
            finished = true
            subscription = nil
            downstream.receive(completion: completion.eraseError())
        }

        func request(_ demand: Subscribers.Demand) {
            subscription?.request(demand)
        }

        func cancel() {
            guard let subscription = self.subscription, !finished else { return }
            subscription.cancel()
            self.subscription = nil
            finished = true
        }

        var description: String { return "Decode" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("finished", finished),
                ("upstreamSubscription", subscription as Any)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
