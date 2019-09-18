//
//  Publishers.Autoconnect.swift
//  
//
//  Created by Sergej Jaskiewicz on 18/09/2019.
//

extension ConnectablePublisher {

    /// Automates the process of connecting or disconnecting from this connectable
    /// publisher.
    ///
    /// Use `autoconnect()` to simplify working with `ConnectablePublisher` instances,
    /// such as those created with `makeConnectable()`.
    ///
    ///     let autoconnectedPublisher = somePublisher
    ///         .makeConnectable()
    ///         .autoconnect()
    ///         .subscribe(someSubscriber)
    ///
    /// - Returns: A publisher which automatically connects to its upstream connectable
    ///   publisher.
    public func autoconnect() -> Publishers.Autoconnect<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {

    /// A publisher that automatically connects and disconnects from this connectable
    /// publisher.
    public class Autoconnect<Upstream: ConnectablePublisher>: Publisher {

        // NOTE: This class has been audited for thread safety

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        private enum State {
            case disconnected
            case connected(refcount: Int, connection: Cancellable)
        }

        /// The publisher from which this publisher receives elements.
        public final let upstream: Upstream

        private let lock = Lock(recursive: false)

        private var state = State.disconnected

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(parent: self, downstream: subscriber)
            lock.lock()
            switch state {
            case let .connected(refcount, connection):
                state = .connected(refcount: refcount + 1, connection: connection)
                lock.unlock()
                upstream.subscribe(inner)
            case .disconnected:
                lock.unlock()
                upstream.subscribe(inner)
                let connection = upstream.connect()
                lock.lock()
                state = .connected(refcount: 1, connection: connection)
                lock.unlock()
            }
        }

        fileprivate func cancelled() {
            lock.lock()
            switch state {
            case let .connected(refcount, connection):
                if refcount <= 1 {
                    self.state = .disconnected
                    lock.unlock()
                    connection.cancel()
                } else {
                    state = .connected(refcount: refcount - 1, connection: connection)
                    lock.unlock()
                }
            case .disconnected:
                lock.unlock()
            }
        }
    }
}

extension Publishers.Autoconnect {

    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        fileprivate let combineIdentifier: CombineIdentifier

        private let parent: Publishers.Autoconnect<Upstream>

        private let downstream: Downstream

        fileprivate init(parent: Publishers.Autoconnect<Upstream>,
                         downstream: Downstream) {
            combineIdentifier = .init()
            self.parent = parent
            self.downstream = downstream
        }

        fileprivate func receive(subscription: Subscription) {
            let sideEffectSubscription =
                SideEffectSubscription(subscription, onCancel: parent.cancelled)
            downstream.receive(subscription: sideEffectSubscription)
        }

        fileprivate func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        fileprivate func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

        fileprivate var description: String { return "Autoconnect" }

        fileprivate var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("parent", parent),
                ("downstream", downstream)
            ]
            return Mirror(self, children: children)
        }

        fileprivate var playgroundDescription: Any { return description }
    }

    private struct SideEffectSubscription
        : Subscription,
          CustomStringConvertible,
          CustomPlaygroundDisplayConvertible
    {
        private let onCancel: () -> Void

        private let upstreamSubscription: Subscription

        fileprivate init(_ upstreamSubscription: Subscription,
                         onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
            self.upstreamSubscription = upstreamSubscription
        }

        fileprivate func request(_ demand: Subscribers.Demand) {
            upstreamSubscription.request(demand)
        }

        fileprivate func cancel() {
            onCancel()
            upstreamSubscription.cancel()
        }

        fileprivate var combineIdentifier: CombineIdentifier {
            return upstreamSubscription.combineIdentifier
        }

        fileprivate var description: String {
            return String(describing: upstreamSubscription)
        }

        var playgroundDescription: Any {
            return description
        }
    }
}
