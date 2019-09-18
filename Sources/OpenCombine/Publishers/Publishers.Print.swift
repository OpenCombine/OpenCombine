//
//  Publishers.Print.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

extension Publishers {

    /// A publisher that prints log messages for all publishing events, optionally
    /// prefixed with a given string.
    ///
    /// This publisher prints log messages when receiving the following events:
    /// * subscription
    /// * value
    /// * normal completion
    /// * failure
    /// * cancellation
    public struct Print<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// A string with which to prefix all log messages.
        public let prefix: String

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public let stream: TextOutputStream?

        /// Creates a publisher that prints log messages for all publishing events.
        ///
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        ///   - prefix: A string with which to prefix all log messages.
        public init(upstream: Upstream,
                    prefix: String,
                    to stream: TextOutputStream? = nil) {
            self.upstream = upstream
            self.prefix = prefix
            self.stream = stream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, prefix: prefix, stream: stream)
            upstream.subscribe(inner)
        }
    }
}

extension Publisher {

    /// Prints log messages for all publishing events.
    ///
    /// - Parameter prefix: A string with which to prefix all log messages. Defaults to
    ///   an empty string.
    /// - Returns: A publisher that prints log messages for all publishing events.
    public func print(_ prefix: String = "",
                      to stream: TextOutputStream? = nil) -> Publishers.Print<Self> {
        return Publishers.Print(upstream: self, prefix: prefix, to: stream)
    }
}

extension Publishers.Print {
    private final class Inner<Downstream: Subscriber>: Subscriber,
                                                       Subscription,
                                                       CustomStringConvertible,
                                                       CustomReflectable
    {
        typealias Input = Downstream.Input
        typealias Failure = Downstream.Failure

        /// A concrete type wrapper around an abstract stream.
        private struct PrintTarget: TextOutputStream {

            var stream: TextOutputStream

            mutating func write(_ string: String) {
                stream.write(string)
            }
        }

        private var downstream: Downstream
        private let prefix: String
        private var stream: PrintTarget?
        private var subscription: Subscription?
        private let lock = Lock(recursive: false)

        init(downstream: Downstream, prefix: String, stream: TextOutputStream?) {
            self.downstream = downstream
            self.prefix = prefix.isEmpty ? "" : "\(prefix): "
            self.stream = stream.map(PrintTarget.init)
        }

        func receive(subscription: Subscription) {
            log("\(prefix)receive subscription: (\(subscription))")
            lock.do {
                self.subscription = subscription
            }
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            log("\(prefix)receive value: (\(input))")
            let demand = downstream.receive(input)

            if let max = demand.max {
                log("\(prefix)request max: (\(max)) (synchronous)")
            } else {
                log("\(prefix)request unlimited (synchronous)")
            }

            return demand
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                log("\(prefix)receive finished")
            case .failure(let error):
                log("\(prefix)receive error: (\(error))")
            }
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            if let max = demand.max {
                log("\(prefix)request max: (\(max))")
            } else {
                log("\(prefix)request unlimited")
            }
            subscription?.request(demand)
        }

        func cancel() {
            log("\(prefix)receive cancel")
            subscription?.cancel()
            subscription = nil
        }

        var description: String { return "Print" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        private func log(_ text: String) {
            if var stream = stream {
                Swift.print(text, to: &stream)
            } else {
                Swift.print("", text)
            }
        }
    }
}
