//
//  Publishers.Buffer.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.01.2020.
//

extension Publisher {

    /// Buffers elements received from an upstream publisher.
    /// - Parameter size: The maximum number of elements to store.
    /// - Parameter prefetch: The strategy for initially populating the buffer.
    /// - Parameter whenFull: The action to take when the buffer becomes full.
    public func buffer(
        size: Int,
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<Failure>
    ) -> Publishers.Buffer<Self> {
        return .init(upstream: self,
                     size: size,
                     prefetch: prefetch,
                     whenFull: whenFull)
    }
}

extension Publishers {

    /// A strategy for filling a buffer.
    ///
    /// * keepFull: A strategy to fill the buffer at subscription time, and keep it full
    ///   thereafter.
    /// * byRequest: A strategy that avoids prefetching and instead performs requests
    ///   on demand.
    public enum PrefetchStrategy {

        /// A strategy to fill the buffer at subscription time, and keep it full
        /// thereafter.
        case keepFull

        /// A strategy that avoids prefetching and instead performs requests
        /// on demand.
        case byRequest
    }

    /// A strategy for handling exhaustion of a buffer’s capacity.
    ///
    /// * dropNewest: When full, discard the newly-received element without buffering it.
    /// * dropOldest: When full, remove the least recently-received element from the
    ///   buffer.
    /// * customError: When full, execute the closure to provide a custom error.
    public enum BufferingStrategy<Failure: Error> {

        /// When full, discard the newly-received element without buffering it.
        case dropNewest

        /// When full, remove the least recently-received element from the buffer.
        case dropOldest

        /// When full, execute the closure to provide a custom error.
        case customError(() -> Failure)
    }

    /// A publisher that buffers elements received from an upstream publisher.
    public struct Buffer<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The maximum number of elements to store.
        public let size: Int

        /// The strategy for initially populating the buffer.
        public let prefetch: Publishers.PrefetchStrategy

        /// The action to take when the buffer becomes full.
        public let whenFull: Publishers.BufferingStrategy<Failure>

        /// Creates a publisher that buffers elements received from an upstream publisher.
        /// - Parameter upstream: The publisher from which this publisher receives
        ///   elements.
        /// - Parameter size: The maximum number of elements to store.
        /// - Parameter prefetch: The strategy for initially populating the buffer.
        /// - Parameter whenFull: The action to take when the buffer becomes full.
        public init(upstream: Upstream,
                    size: Int,
                    prefetch: Publishers.PrefetchStrategy,
                    whenFull: Publishers.BufferingStrategy<Failure>) {
            self.upstream = upstream
            self.size = size
            self.prefetch = prefetch
            self.whenFull = whenFull
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, buffer: self))
        }
    }
}

extension Publishers.PrefetchStrategy: Equatable {}

extension Publishers.PrefetchStrategy: Hashable {}

extension Publishers.Buffer {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private enum State {
            case ready(Publishers.Buffer<Upstream>, Downstream)
            case subscribed(Publishers.Buffer<Upstream>, Downstream, Subscription)
            case terminal
        }

        private let lock = UnfairLock.allocate()

        private var recursion = false

        private var state: State

        private var downstreamDemand = Subscribers.Demand.none

        // TODO: Use a deque here?
        // Need to measure performance with large buffers and `dropOldest` strategy.
        private var values = [Input]()

        private var upstreamFailed = false

        private var terminal: Subscribers.Completion<Failure>?

        init(downstream: Downstream, buffer: Publishers.Buffer<Upstream>) {
            state = .ready(buffer, downstream)
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(buffer, downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(buffer, downstream, subscription)
            lock.unlock()

            let upstreamDemand: Subscribers.Demand
            switch buffer.prefetch {
            case .keepFull:
                upstreamDemand = .max(buffer.size)
            case .byRequest:
                upstreamDemand = .unlimited
            }
            subscription.request(upstreamDemand)
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(buffer, _, subscription) = state else {
                lock.unlock()
                return .none
            }
            switch terminal {
            case nil, .finished?:
                if values.count >= buffer.size {
                    switch buffer.whenFull {
                    case .dropNewest:
                        lock.unlock()
                        return drain()
                    case .dropOldest:
                        values.removeFirst()
                    case let .customError(makeError):
                        terminal = .failure(makeError())
                        lock.unlock()
                        subscription.cancel()
                        return .none
                    }
                }

                values.append(input)
                lock.unlock()
                return drain()
            case .failure?:
                lock.unlock()
                return .none
            }
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            guard case .subscribed = state, terminal == nil else {
                lock.unlock()
                return
            }
            terminal = completion
            lock.unlock()
            _ = drain()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(_, _, subscription) = state else {
                lock.unlock()
                return
            }
            downstreamDemand += demand
            let recursion = self.recursion
            lock.unlock()
            if recursion {
                return
            }

            // Request the number of items just enough to fill the buffer.
            subscription.request(drain() + demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(_, _, subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            values = []
            lock.unlock()
            subscription.cancel()
        }

        private func drain() -> Subscribers.Demand {
            var upstreamDemand = Subscribers.Demand.none
            lock.lock()
            while true {
                guard case let .subscribed(buffer, downstream, _) = state,
                      downstreamDemand > 0 else {
                    lock.unlock()
                    return upstreamDemand
                }

                if values.isEmpty {
                    if let completion = terminal {
                        state = .terminal
                        lock.unlock()
                        downstream.receive(completion: completion)
                    } else {
                        lock.unlock()
                    }
                    return upstreamDemand
                }

                let poppedValues = lockedPop(downstreamDemand)
                assert(poppedValues.count > 0,
                       """
                       We check that the buffer is not empty and downstreamDemand is \
                       nonzero, how can this be triggered?
                       """)

                // This should not crash because `lockedPop(_:)` returns at most
                // `downstreamDemand` items.
                downstreamDemand -= poppedValues.count

                recursion = true
                lock.unlock()

                var newDownstreamDemand = Subscribers.Demand.none
                var additionalUpstreamDemand = 0

                for value in poppedValues {
                    newDownstreamDemand += downstream.receive(value)
                    additionalUpstreamDemand += 1
                }

                if buffer.prefetch == .keepFull {
                    upstreamDemand += additionalUpstreamDemand
                }

                lock.lock()
                recursion = false
                downstreamDemand += newDownstreamDemand
            }
        }

        private func lockedPop(_ demand: Subscribers.Demand) -> [Input] {
            assert(demand > 0)
            guard let max = demand.max else {
                let poppedValues = self.values
                self.values = []
                return poppedValues
            }

            let poppedValues = Array(values.prefix(max))
            values.removeFirst(poppedValues.count)
            return poppedValues
        }

        var description: String { return "Buffer" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("values", values),
                ("state", state),
                ("downstreamDemand", downstreamDemand),
                ("terminal", terminal as Any)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
