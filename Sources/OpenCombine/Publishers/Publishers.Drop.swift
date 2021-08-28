//
//  Publishers.Drop.swift
//
//
//  Created by Sven Weidauer on 03.10.2019.
//

extension Publisher {
    /// Omits the specified number of elements before republishing subsequent elements.
    ///
    /// Use `dropFirst(_:)` when you want to drop the first `n` elements from the upstream
    /// publisher, and republish the remaining elements.
    ///
    /// The example below drops the first five elements from the stream:
    ///
    ///     let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    ///     cancellable = numbers.publisher
    ///         .dropFirst(5)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "6 7 8 9 10 "
    ///
    /// - Parameter count: The number of elements to omit. The default is `1`.
    /// - Returns: A publisher that doesn’t republish the first `count` elements.
    public func dropFirst(_ count: Int = 1) -> Publishers.Drop<Self> {
        return .init(upstream: self, count: count)
    }
}

extension Publishers {
    /// A publisher that omits a specified number of elements before republishing
    /// later elements.
    public struct Drop<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The number of elements to drop.
        public let count: Int

        public init(upstream: Upstream, count: Int) {
            self.upstream = upstream
            self.count = count
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, count: count)
            subscriber.receive(subscription: inner)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Drop: Equatable where Upstream: Equatable {}

extension Publishers.Drop {
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input,
              Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let lock = UnfairLock.allocate()

        private var subscription: Subscription?

        private var pendingDemand = Subscribers.Demand.none

        private var count: Int

        fileprivate init(downstream: Downstream, count: Int) {
            self.downstream = downstream
            self.count = count
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard self.subscription == nil else {
                lock.unlock()
                subscription.cancel()
                return
            }
            self.subscription = subscription
            precondition(count >= 0, "count must not be negative")
            let demandToRequestFromUpstream = pendingDemand + count
            lock.unlock()
            if demandToRequestFromUpstream != .none {
                subscription.request(demandToRequestFromUpstream)
            }
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            // Combine doesn't lock here!
            if count > 0 {
                count -= 1
                return .none
            }
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            subscription = nil
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let subscription = self.subscription else {
                self.pendingDemand += demand
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            let subscription = self.subscription.take()
            lock.unlock()
            subscription?.cancel()
        }

        var description: String { return "Drop" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}
