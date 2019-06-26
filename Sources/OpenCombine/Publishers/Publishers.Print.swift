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

        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Failure == SubscriberType.Failure, Output == SubscriberType.Input
        {
            let inner = Inner(downstream: subscriber, prefix: prefix, stream: stream)
            upstream.receive(subscriber: inner)
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

private final class Inner<Downstream: Subscriber>: Subscriber,
                                                   Subscription,
                                                   CustomStringConvertible,
                                                   CustomReflectable
{
    typealias Input = Downstream.Input
    typealias Failure = Downstream.Failure

    private var _downstream: Downstream
    private let _prefix: String
    private var _stream: TextOutputStream
    private var _upstreamSubscription: Subscription?
    private let _printerLock = Lock(recursive: false)

    init(downstream: Downstream, prefix: String, stream: TextOutputStream?) {
        _downstream = downstream
        _prefix = prefix
        _stream = stream ?? StdoutStream()
    }

    func receive(subscription: Subscription) {
        _log("receive subscription", value: subscription)
        _upstreamSubscription = subscription
        _downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        _log("receive value", value: input)
        let demand = _downstream.receive(input)
        _logDemand(demand, synchronous: true)
        return demand
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        switch completion {
        case .finished:
            _log("receive finished")
        case .failure(let error):
            _log("receive error", value: error)
        }
        _downstream.receive(completion: completion)
    }

    func request(_ demand: Subscribers.Demand) {
        _logDemand(demand, synchronous: false)
        _upstreamSubscription?.request(demand)
    }

    func cancel() {
        _log("receive cancel")
        _upstreamSubscription?.cancel()
        _upstreamSubscription = nil
    }

    var description: String { return "Print" }

    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

    private func _log(_ description: String,
                      value: Any? = nil,
                      additionalInfo: String = "") {
        _printerLock.do {
            if !_prefix.isEmpty {
                _stream.write(_prefix)
                _stream.write(": ")
            }
            _stream.write(description)
            if let value = value {
                _stream.write(": (")
                _stream.write(String(describing: value))
                _stream.write(")")
            }
            if !additionalInfo.isEmpty {
                _stream.write(" (")
                _stream.write(additionalInfo)
                _stream.write(")")
            }
            _stream.write("\n")
        }
    }

    private func _logDemand(_ demand: Subscribers.Demand, synchronous: Bool) {
        let synchronouslyStr = synchronous ? "synchronous" : ""
        switch demand {
        case .max(let max):
            _log("request max", value: max, additionalInfo: synchronouslyStr)
        case .unlimited:
            _log("request unlimited", additionalInfo: synchronouslyStr)
        }
    }
}

private struct StdoutStream: TextOutputStream {
    mutating func write(_ string: String) {
        print(string, terminator: "")
    }
}
