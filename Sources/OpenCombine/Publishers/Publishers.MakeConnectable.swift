//
//  Publishers.MakeConnectable.swift
//  
//
//  Created by Sergej Jaskiewicz on 18/09/2019.
//

extension Publisher where Failure == Never {

    /// Creates a connectable wrapper around the publisher.
    ///
    /// - Returns: A `ConnectablePublisher` wrapping this publisher.
    public func makeConnectable() -> Publishers.MakeConnectable<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {

    public struct MakeConnectable<Upstream: Publisher>: ConnectablePublisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        private let inner: Multicast<Upstream, PassthroughSubject<Output, Failure>>

        public init(upstream: Upstream) {
            inner = upstream.multicast(subject: .init())
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure, Downstream.Input == Output
        {
            inner.subscribe(subscriber)
        }

        public func connect() -> Cancellable {
            return inner.connect()
        }
    }
}
