//
//  Publishers.DropWhile.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

extension Publisher {

    /// Omits elements from the upstream publisher until a given closure returns false,
    /// before republishing all remaining elements.
    ///
    /// Use `drop(while:)` to omit elements from an upstream publisher until the element
    /// received meets a condition you specify.
    ///
    /// In the example below, the operator omits all elements in the stream until
    /// the first element arrives that’s a positive integer, after which the operator
    /// publishes all remaining elements:
    ///
    ///     let numbers = [-62, -1, 0, 10, 0, 22, 41, -1, 5]
    ///     cancellable = numbers.publisher
    ///         .drop { $0 <= 0 }
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "10 0 22 41 -1 5"
    ///
    ///
    /// - Parameter predicate: A closure that takes an element as a parameter and returns
    ///   a Boolean value indicating whether to drop the element from the publisher’s
    ///   output.
    /// - Returns: A publisher that skips over elements until the provided closure returns
    ///   `false`.
    public func drop(
        while predicate: @escaping (Output) -> Bool
    ) -> Publishers.DropWhile<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Omits elements from the upstream publisher until an error-throwing closure returns
    /// false, before republishing all remaining elements.
    ///
    /// Use `Publisher/tryDrop(while:)` to omit elements from an upstream until
    /// an error-throwing closure you provide returns false, after which the remaining
    /// items in the stream are published. If the closure throws, no elements are emitted
    /// and the publisher fails with an error.
    ///
    /// In the example below, elements are ignored until `-1` is encountered in the stream
    /// and the closure returns `false`. The publisher then republishes the remaining
    /// elements and finishes normally. Conversely, if the `guard` value in the closure
    /// had been encountered, the closure would throw and the publisher would fail with
    /// an error.
    ///
    ///     struct RangeError: Error {}
    ///     var numbers = [1, 2, 3, 4, 5, 6, -1, 7, 8, 9, 10]
    ///     let range: CountableClosedRange<Int> = (1...100)
    ///     cancellable = numbers.publisher
    ///         .tryDrop {
    ///             guard $0 != 0 else { throw RangeError() }
    ///             return range.contains($0)
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)") },
    ///             receiveValue: { print ("value: \($0)") }
    ///         )
    ///
    ///     // Prints: "-1 7 8 9 10 completion: finished"
    ///     // If instead numbers was [1, 2, 3, 4, 5, 6, 0, -1, 7, 8, 9, 10],
    ///     // tryDrop(while:) would fail with a RangeError.
    ///
    /// - Parameter predicate: A closure that takes an element as a parameter and returns
    ///   a Boolean value indicating whether to drop the element from the publisher’s
    ///   output.
    /// - Returns: A publisher that skips over elements until the provided closure returns
    ///   `false`, and then republishes all remaining elements. If the predicate closure
    ///   throws, the publisher fails with an error.
    public func tryDrop(
        while predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryDropWhile<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {

    /// A publisher that omits elements from an upstream publisher until a given closure
    /// returns false.
    public struct DropWhile<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that indicates whether to drop the element.
        public let predicate: (Output) -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }

    /// A publisher that omits elements from an upstream publisher until a given
    /// error-throwing closure returns false.
    public struct TryDropWhile<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that indicates whether to drop the element.
        public let predicate: (Upstream.Output) throws -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Output == Downstream.Input, Downstream.Failure == Error
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }
}

extension Publishers.DropWhile {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input, Downstream.Failure == Upstream.Failure
    {
        // NOTE: This class has been audited for thread safety.

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private var status = SubscriptionStatus.awaitingSubscription

        private let downstream: Downstream

        private var predicate: ((Input) -> Bool)?

        private var dropping = true

        private let lock = UnfairLock.allocate()

        fileprivate init(downstream: Downstream, predicate: @escaping (Input) -> Bool) {
            self.downstream = downstream
            self.predicate = predicate
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = status, let shouldDrop = predicate else {
                lock.unlock()
                return .none
            }
            let dropping = self.dropping
            lock.unlock()

            if dropping {
                if shouldDrop(input) {
                    return .max(1)
                } else {
                    lock.lock()
                    self.dropping = false
                    lock.unlock()
                }
            }

            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return
            }
            status = .terminal
            predicate = nil
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal
            predicate = nil
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "DropWhile" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryDropWhile {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input, Downstream.Failure == Error
    {
        // NOTE: This class has been audited for thread safety.

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private var status = SubscriptionStatus.awaitingSubscription

        private let downstream: Downstream

        private var predicate: ((Input) throws -> Bool)?

        private var dropping = true

        private var finished = false

        private let lock = UnfairLock.allocate()

        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Input) throws -> Bool) {
            self.downstream = downstream
            self.predicate = predicate
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(subscription) = status,
                  let shouldDrop = predicate else {
                lock.unlock()
                return .none
            }
            let dropping = self.dropping
            lock.unlock()

            if dropping {
                do {
                    if try shouldDrop(input) {
                        return .max(1)
                    } else {
                        lock.lock()
                        self.dropping = false
                        lock.unlock()
                    }
                } catch {
                    lock.lock()
                    status = .terminal
                    predicate = nil
                    finished = true
                    lock.unlock()
                    subscription.cancel()
                    downstream.receive(completion: .failure(error))
                    return .none
                }
            }

            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return
            }
            status = .terminal
            let wasFinished = finished
            finished = true
            lock.unlock()

            if !wasFinished {
                downstream.receive(completion: completion.eraseError())
            }
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal
            predicate = nil
            finished = true
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "TryDropWhile" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
