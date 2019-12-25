//
//  Publishers.CollectByCount.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.12.2019.
//

extension Publisher {

    /// Collects up to the specified number of elements, and then emits a single array of
    /// the collection.
    ///
    /// If the upstream publisher finishes before filling the buffer, this publisher sends
    /// an array of all the items it has received. This may be fewer than `count`
    /// elements.
    /// If the upstream publisher fails with an error, this publisher forwards the error
    /// to the downstream receiver instead of sending its output.
    /// Note: When this publisher receives a request for `.max(n)` elements, it requests
    /// `.max(count * n)` from the upstream publisher.
    ///
    /// - Parameter count: The maximum number of received elements to buffer before
    ///   publishing.
    /// - Returns: A publisher that collects up to the specified number of elements, and
    ///   then publishes them as an array.
    public func collect(_ count: Int) -> Publishers.CollectByCount<Self> {
        return .init(upstream: self, count: count)
    }
}

extension Publishers {

    /// A publisher that buffers a maximum number of items.
    public struct CollectByCount<Upstream: Publisher>: Publisher {

        public typealias Output = [Upstream.Output]

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        ///  The maximum number of received elements to buffer before publishing.
        public let count: Int

        public init(upstream: Upstream, count: Int) {
            self.upstream = upstream
            self.count = count
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure, Downstream.Input == Output
        {
            upstream.subscribe(Inner(downstream: subscriber, count: count))
        }
    }
}

extension Publishers.CollectByCount: Equatable where Upstream: Equatable {}

extension Publishers.CollectByCount {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == [Upstream.Output],
              Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let count: Int

        private var buffer: [Input] = []

        private var subscription: Subscription?

        private var finished = false

        private let lock = UnfairLock.allocate()

        init(downstream: Downstream, count: Int) {
            self.downstream = downstream
            self.count = count
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

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            if subscription == nil {
                lock.unlock()
                return .none
            }
            buffer.append(input)
            guard buffer.count == count else {
                lock.unlock()
                return .none
            }
            let output = self.buffer
            self.buffer = []
            lock.unlock()
            return downstream.receive(output) * count
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            subscription = nil
            finished = true
            switch completion {
            case .finished:
                if buffer.isEmpty {
                    lock.unlock()
                } else {
                    let buffer = self.buffer
                    self.buffer = []
                    lock.unlock()
                    _ = downstream.receive(buffer)
                }
            case .failure:
                buffer = []
                lock.unlock()
            }
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            if let subscription = self.subscription {
                lock.unlock()
                subscription.request(demand * count)
            } else {
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            if let subscription = self.subscription {
                buffer = []
                finished = true
                self.subscription = nil
                lock.unlock()
                subscription.cancel()
            } else {
                lock.unlock()
            }
        }

        var description: String { return "CollectByCount" }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("upstreamSubscription", subscription as Any),
                ("buffer", buffer),
                ("count", count)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
