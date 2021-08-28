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

    /// Encodes the output from upstream using a specified encoder.
    ///
    /// Use `encode(encoder:)` with a `JSONDecoder` (or a `PropertyListDecoder` for
    /// property lists) to encode an `Encodable` struct into `Data` that could be used to
    /// make a JSON string (or written to disk as a binary plist in the case of property
    /// lists).
    ///
    /// In this example, a `PassthroughSubject` publishes an `Article`.
    /// The `encode(encoder:)` operator encodes the properties of the `Article` struct
    /// into a new JSON string according to the `Codable` protocol adopted by `Article`.
    /// The operator publishes the resulting JSON string to the downstream subscriber.
    /// If the encoding operation fails, which can happen in the case of complex
    /// properties that can’t be directly transformed into JSON, the stream terminates
    /// and the error is passed to the downstream subscriber.
    ///
    ///     struct Article: Codable {
    ///         let title: String
    ///         let author: String
    ///         let pubDate: Date
    ///     }
    ///
    ///     let dataProvider = PassthroughSubject<Article, Never>()
    ///     let cancellable = dataProvider
    ///         .encode(encoder: JSONEncoder())
    ///         .sink(receiveCompletion: { print ("Completion: \($0)") },
    ///               receiveValue: {  data in
    ///                 guard let stringRepresentation =
    ///                     String(data: data, encoding: .utf8) else { return }
    ///                 print("""
    ///                       Data received \(data) string representation: \
    ///                       \(stringRepresentation)
    ///                       """)
    ///         })
    ///
    ///     dataProvider.send(Article(title: "My First Article",
    ///                               author: "Gita Kumar",
    ///                               pubDate: Date()))
    ///
    ///     // Prints: "Data received 86 bytes string representation:
    ///     // {"title":"My First Article","author":"Gita Kumar"
    ///     // "pubDate":606211803.279603}"
    ///
    /// - Parameter encoder: An encoder that implements the `TopLevelEncoder` protocol.
    /// - Returns: A publisher that encodes received elements using a specified encoder,
    ///   and publishes the resulting data.
    public func encode<Coder: TopLevelEncoder>(
        encoder: Coder
    ) -> Publishers.Encode<Self, Coder> {
        return .init(upstream: self, encoder: encoder)
    }

    /// Decodes the output from the upstream using a specified decoder.
    ///
    /// Use `decode(type:decoder:)` with a `JSONDecoder` (or a `PropertyListDecoder` for
    /// property lists) to decode data received from a `URLSession.DataTaskPublisher` or
    /// other data source using the `Decodable` protocol.
    ///
    /// In this example, a `PassthroughSubject` publishes a JSON string. The JSON decoder
    /// parses the string, converting its fields according to the `Decodable` protocol
    /// implemented by `Article`, and successfully populating a new `Article`.
    /// The `Publishers.Decode` publisher then publishes the `Article` to the downstream.
    /// If a decoding operation fails, which happens in the case of missing or malformed
    /// data in the source JSON string, the stream terminates and passes the error to
    /// the downstream subscriber.
    ///
    ///     struct Article: Codable {
    ///         let title: String
    ///         let author: String
    ///         let pubDate: Date
    ///     }
    ///
    ///     let dataProvider = PassthroughSubject<Data, Never>()
    ///     cancellable = dataProvider
    ///         .decode(type: Article.self, decoder: JSONDecoder())
    ///         .sink(receiveCompletion: { print ("Completion: \($0)")},
    ///               receiveValue: { print ("value: \($0)") })
    ///
    ///     dataProvider.send(Data("""
    ///                            {\"pubDate\":1574273638.575666, \
    ///                            \"title\" : \"My First Article\", \
    ///                            \"author\" : \"Gita Kumar\" }
    ///                            """.utf8))
    ///
    ///     // Prints:
    ///     // ".sink() data received Article(title: "My First Article",
    ///     //                                author: "Gita Kumar",
    ///     //                                pubDate: 2050-11-20 18:13:58 +0000)"
    ///
    /// - Parameters:
    ///   - type: The encoded data to decode into a struct that conforms to
    ///     the `Decodable` protocol.
    ///   - decoder:  A decoder that implements the `TopLevelDecoder` protocol.
    /// - Returns: A publisher that decodes a given type using a specified decoder and
    ///   publishes the result.
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
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let encode: (Upstream.Output) throws -> Output

        private let lock = UnfairLock.allocate()

        private var finished = false

        private var subscription: Subscription?

        fileprivate init(
            downstream: Downstream,
            encode: @escaping (Upstream.Output) throws -> Output
        ) {
            self.downstream = downstream
            self.encode = encode
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            if finished || self.subscription != nil {
                lock.unlock()
                subscription.cancel()
                return
            }
            self.subscription = subscription
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            if finished {
                lock.unlock()
                return .none
            }
            lock.unlock()
            do {
                return try downstream.receive(encode(input))
            } catch {
                lock.lock()
                finished = true
                let subscription = self.subscription.take()
                lock.unlock()
                subscription?.cancel()
                downstream.receive(completion: .failure(error))
                return .none
            }
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            if finished {
                lock.unlock()
                return
            }
            finished = true
            subscription = nil
            lock.unlock()
            downstream.receive(completion: completion.eraseError())
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            let subscription = self.subscription
            lock.unlock()
            subscription?.request(demand)
        }

        func cancel() {
            lock.lock()
            guard !finished, let subscription = self.subscription.take() else {
                lock.unlock()
                return
            }
            finished = true
            lock.unlock()
            subscription.cancel()
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
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let decode: (Upstream.Output) throws -> Output

        private let lock = UnfairLock.allocate()

        private var finished = false

        private var subscription: Subscription?

        fileprivate init(
            downstream: Downstream,
            decode: @escaping (Upstream.Output) throws -> Output
        ) {
            self.downstream = downstream
            self.decode = decode
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            if finished || self.subscription != nil {
                lock.unlock()
                subscription.cancel()
                return
            }
            self.subscription = subscription
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            if finished {
                lock.unlock()
                return .none
            }
            lock.unlock()
            do {
                return try downstream.receive(decode(input))
            } catch {
                lock.lock()
                finished = true
                let subscription = self.subscription.take()
                lock.unlock()
                subscription?.cancel()
                downstream.receive(completion: .failure(error))
                return .none
            }
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            if finished {
                lock.unlock()
                return
            }
            finished = true
            subscription = nil
            lock.unlock()
            downstream.receive(completion: completion.eraseError())
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            let subscription = self.subscription
            lock.unlock()
            subscription?.request(demand)
        }

        func cancel() {
            lock.lock()
            guard !finished, let subscription = self.subscription.take() else {
                lock.unlock()
                return
            }
            finished = true
            lock.unlock()
            subscription.cancel()
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
