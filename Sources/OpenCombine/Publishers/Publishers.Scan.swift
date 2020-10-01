//
//  Publishers.Scan.swift
//
//  Created by Eric Patey on 26.08.2019.
//

extension Publisher {

    /// Transforms elements from the upstream publisher by providing the current
    /// element to a closure along with the last value returned by the closure.
    ///
    /// Use `scan(_:_:)` to accumulate all previously-published values into a single
    /// value, which you then combine with each newly-published value.
    ///
    /// The following example logs a running total of all values received
    /// from the sequence publisher.
    ///
    ///     let range = (0...5)
    ///     cancellable = range.publisher
    ///         .scan(0) { return $0 + $1 }
    ///         .sink { print ("\($0)", terminator: " ") }
    ///      // Prints: "0 1 3 6 10 15 ".
    ///
    /// - Parameters:
    ///   - initialResult: The previous result returned by the `nextPartialResult`
    ///     closure.
    ///   - nextPartialResult: A closure that takes as its arguments the previous value
    ///     returned by the closure and the next element emitted from the upstream
    ///     publisher.
    /// - Returns: A publisher that transforms elements by applying a closure that
    ///   receives its previous return value and the next element from the upstream
    ///   publisher.
    public func scan<Result>(
        _ initialResult: Result,
        _ nextPartialResult: @escaping (Result, Output) -> Result
    ) -> Publishers.Scan<Self, Result> {
        return .init(upstream: self,
                     initialResult: initialResult,
                     nextPartialResult: nextPartialResult)
    }

    /// Transforms elements from the upstream publisher by providing the current element
    /// to an error-throwing closure along with the last value returned by the closure.
    ///
    /// Use `tryScan(_:_:)` to accumulate all previously-published values into a single
    /// value, which you then combine with each newly-published value.
    /// If your accumulator closure throws an error, the publisher terminates with
    /// the error.
    ///
    /// In the example below, `tryScan(_:_:)` calls a division function on elements of
    /// a collection publisher. The `Publishers.TryScan` publisher publishes each result
    /// until the function encounters a `DivisionByZeroError`, which terminates
    /// the publisher.
    ///
    ///     struct DivisionByZeroError: Error {}
    ///
    ///     /// A function that throws a DivisionByZeroError if `current` provided by the
    ///     /// TryScan publisher is zero.
    ///     func myThrowingFunction(_ lastValue: Int, _ currentValue: Int) throws -> Int {
    ///         guard currentValue != 0 else { throw DivisionByZeroError() }
    ///         return (lastValue + currentValue) / currentValue
    ///      }
    ///
    ///     let numbers = [1,2,3,4,5,0,6,7,8,9]
    ///     cancellable = numbers.publisher
    ///         .tryScan(10) { try myThrowingFunction($0, $1) }
    ///         .sink(
    ///             receiveCompletion: { print ("\($0)") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///          )
    ///
    ///     // Prints: "11 6 3 1 1 -1 failure(DivisionByZeroError())".
    ///
    /// If the closure throws an error, the publisher fails with the error.
    ///
    /// - Parameters:
    ///   - initialResult: The previous result returned by the `nextPartialResult`
    ///     closure.
    ///   - nextPartialResult: An error-throwing closure that takes as its arguments the
    ///     previous value returned by the closure and the next element emitted from the
    ///     upstream publisher.
    /// - Returns: A publisher that transforms elements by applying a closure that
    ///   receives its previous return value and the next element from the upstream
    ///   publisher.
    public func tryScan<Result>(
        _ initialResult: Result,
        _ nextPartialResult: @escaping (Result, Output) throws -> Result
    ) -> Publishers.TryScan<Self, Result> {
        return .init(upstream: self,
                     initialResult: initialResult,
                     nextPartialResult: nextPartialResult)
    }
}

extension Publishers {

    public struct Scan<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Upstream.Failure

        public let upstream: Upstream

        public let initialResult: Output

        public let nextPartialResult: (Output, Upstream.Output) -> Output

        public init(upstream: Upstream,
                    initialResult: Output,
                    nextPartialResult: @escaping (Output, Upstream.Output) -> Output) {
            self.upstream = upstream
            self.initialResult = initialResult
            self.nextPartialResult = nextPartialResult
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Output == Downstream.Input, Upstream.Failure == Downstream.Failure
        {
            upstream.subscribe(Inner(downstream: subscriber,
                                     initialResult: initialResult,
                                     nextPartialResult: nextPartialResult))
        }
    }

    public struct TryScan<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Error

        public let upstream: Upstream

        public let initialResult: Output

        public let nextPartialResult: (Output, Upstream.Output) throws -> Output

        public init(
            upstream: Upstream,
            initialResult: Output,
            nextPartialResult: @escaping (Output, Upstream.Output) throws -> Output
        ) {
            self.upstream = upstream
            self.initialResult = initialResult
            self.nextPartialResult = nextPartialResult
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Output == Downstream.Input, Downstream.Failure == Error
        {
            upstream.subscribe(Inner(downstream: subscriber,
                                     initialResult: initialResult,
                                     nextPartialResult: nextPartialResult))
        }
    }
}

extension Publishers.Scan {

    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Failure == Downstream.Failure
    {
        // NOTE: this class has been audited for thread safety.
        // Combine doesn't use any locking here.

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let nextPartialResult: (Downstream.Input, Input) -> Downstream.Input

        private var result: Downstream.Input

        fileprivate init(
            downstream: Downstream,
            initialResult: Downstream.Input,
            nextPartialResult: @escaping (Downstream.Input, Input) -> Downstream.Input
        )
        {
            self.downstream = downstream
            self.result = initialResult
            self.nextPartialResult = nextPartialResult
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            result = nextPartialResult(result, input)
            return downstream.receive(result)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

        var description: String { return "Scan" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("result", result)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryScan {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Failure == Error
    {
        // NOTE: this class has been audited for thread safety.

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let nextPartialResult:
            (Downstream.Input, Input) throws -> Downstream.Input

        private var result: Downstream.Input

        private var status = SubscriptionStatus.awaitingSubscription

        private let lock = UnfairLock.allocate()

        private var finished = false

        fileprivate init(
            downstream: Downstream,
            initialResult: Downstream.Input,
            nextPartialResult:
                @escaping (Downstream.Input, Input) throws -> Downstream.Input
        ) {
            self.downstream = downstream
            self.nextPartialResult = nextPartialResult
            self.result = initialResult
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
            do {
                result = try nextPartialResult(result, input)
                return downstream.receive(result)
            } catch {
                lock.lock()
                guard case let .subscribed(subscription) = status else {
                    lock.unlock()
                    return .none
                }
                status = .terminal
                lock.unlock()
                subscription.cancel()
                downstream.receive(completion: .failure(error))
                return .none
            }
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            // Combine doesn't use locking in this method!
            guard case .subscribed = status else {
                return
            }
            downstream.receive(completion: completion.eraseError())
        }

        func request(_ demand: Subscribers.Demand) {
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
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "TryScan" }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("status", status),
                ("result", result)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
