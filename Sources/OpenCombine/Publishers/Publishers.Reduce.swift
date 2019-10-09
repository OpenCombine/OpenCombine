//
//  Publishers.Reduce.swift
//  
//
//  Created by Sergej Jaskiewicz on 09.10.2019.
//

extension Publisher {

    /// Applies a closure that accumulates each element of a stream and publishes
    /// a final result upon completion.
    ///
    /// - Parameters:
    ///   - initialResult: The value the closure receives the first time it is called.
    ///   - nextPartialResult: A closure that takes the previously-accumulated value and
    ///     the next element from the upstream publisher to produce a new value.
    /// - Returns: A publisher that applies the closure to all received elements and
    ///   produces an accumulated value when the upstream publisher finishes.
    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: @escaping (Accumulator, Output) -> Accumulator
    ) -> Publishers.Reduce<Self, Accumulator> {
        return .init(upstream: self,
                     initial: initialResult,
                     nextPartialResult: nextPartialResult)
    }

    /// Applies an error-throwing closure that accumulates each element of a stream and
    /// publishes a final result upon completion.
    ///
    /// If the closure throws an error, the publisher fails, passing the error
    /// to its subscriber.
    ///
    /// - Parameters:
    ///   - initialResult: The value the closure receives the first time it is called.
    ///   - nextPartialResult: An error-throwing closure that takes
    ///     the previously-accumulated value and the next element from the upstream
    ///     publisher to produce a new value.
    /// - Returns: A publisher that applies the closure to all received elements and
    ///   produces an accumulated value when the upstream publisher finishes.
    public func tryReduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: @escaping (Accumulator, Output) throws -> Accumulator
    ) -> Publishers.TryReduce<Self, Accumulator> {
        return .init(upstream: self,
                     initial: initialResult,
                     nextPartialResult: nextPartialResult)
    }
}

extension Publishers {

    /// A publisher that applies a closure to all received elements and produces
    /// an accumulated value when the upstream publisher finishes.
    public struct Reduce<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Upstream.Failure

        public let upstream: Upstream

        /// The initial value provided on the first invocation of the closure.
        public let initial: Output

        /// A closure that takes the previously-accumulated value and the next element
        /// from the upstream publisher to produce a new value.
        public let nextPartialResult: (Output, Upstream.Output) -> Output

        public init(upstream: Upstream,
                    initial: Output,
                    nextPartialResult: @escaping (Output, Upstream.Output) -> Output) {
            self.upstream = upstream
            self.initial = initial
            self.nextPartialResult = nextPartialResult
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Output == Downstream.Input, Upstream.Failure == Downstream.Failure
        {
            let inner = Inner(downstream: subscriber,
                              initial: initial,
                              reduce: nextPartialResult)
            upstream.subscribe(inner)
        }
    }

    /// A publisher that applies an error-throwing closure to all received elements and
    /// produces an accumulated value when the upstream publisher finishes.
    public struct TryReduce<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The initial value provided on the first invocation of the closure.
        public let initial: Output

        /// An error-throwing closure that takes the previously-accumulated value and
        /// the next element from the upstream to produce a new value.
        ///
        /// If this closure throws an error, the publisher fails and passes the error
        /// to its subscriber.
        public let nextPartialResult: (Output, Upstream.Output) throws -> Output

        public init(
            upstream: Upstream,
            initial: Output,
            nextPartialResult: @escaping (Output, Upstream.Output) throws -> Output
        ) {
            self.upstream = upstream
            self.initial = initial
            self.nextPartialResult = nextPartialResult
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Output == Downstream.Input, Downstream.Failure == Error
        {
            let inner = Inner(downstream: subscriber,
                              initial: initial,
                              reduce: nextPartialResult)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Reduce {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Output,
                         Upstream.Failure,
                         (Output, Upstream.Output) -> Output>
        where Downstream.Input == Output, Upstream.Failure == Downstream.Failure
    {
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            result = reduce(result!, newValue)
            return .continue
        }

        override var description: String { return "Reduce" }
    }
}

extension Publishers.TryReduce {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Output,
                         Upstream.Failure,
                         (Output, Upstream.Output) throws -> Output>
        where Downstream.Input == Output, Downstream.Failure == Error
    {
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            do {
                result = try reduce(result!, newValue)
                return .continue
            } catch {
                return .failure(error)
            }
        }

        override var description: String { return "TryReduce" }
    }
}
