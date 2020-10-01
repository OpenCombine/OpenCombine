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
    /// such as `TimerPublisher` in `OpenCombineFoundation`.
    ///
    /// In the following example, the `Timer.publish()` operator creates
    /// a `TimerPublisher`, which is a `ConnectablePublisher`. As a result, subscribers
    /// don’t receive any values until after a call to `connect()`.
    /// For convenience when working with a single subscriber, the `.autoconnect()`
    /// operator performs the `connect()` call when attached to by the subscriber.
    ///
    ///     cancellable = Timer.publish(every: 1, on: .main, in: .default)
    ///         .autoconnect()
    ///         .sink { date in
    ///             print ("Date now: \(date)")
    ///         }
    /// - Returns: A publisher which automatically connects to its upstream connectable
    ///   publisher.
    public func autoconnect() -> Publishers.Autoconnect<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {

    /// A publisher that automatically connects to an upstream connectable publisher.
    ///
    /// This publisher calls `connect()` on the upstream `ConnectablePublisher` when first
    /// attached to by a subscriber.
    public class Autoconnect<Upstream: ConnectablePublisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        private enum State {
            case disconnected
            case connected(refcount: Int, connection: Cancellable)
        }

        /// The publisher from which this publisher receives elements.
        public final let upstream: Upstream

        private let lock = UnfairLock.allocate()

        private var state = State.disconnected

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        deinit {
            lock.deallocate()
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

        fileprivate func willCancel() {
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

        fileprivate let combineIdentifier = CombineIdentifier()

        private let parent: Publishers.Autoconnect<Upstream>

        private let downstream: Downstream

        fileprivate init(parent: Publishers.Autoconnect<Upstream>,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }

        fileprivate func receive(subscription: Subscription) {
            let sideEffectSubscription = SideEffectSubscription(subscription,
                                                                parent: parent)
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
        private let parent: Publishers.Autoconnect<Upstream>

        private let upstreamSubscription: Subscription

        fileprivate init(_ upstreamSubscription: Subscription,
                         parent: Publishers.Autoconnect<Upstream>) {
            self.parent = parent
            self.upstreamSubscription = upstreamSubscription
        }

        fileprivate func request(_ demand: Subscribers.Demand) {
            upstreamSubscription.request(demand)
        }

        fileprivate func cancel() {
            parent.willCancel()
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
