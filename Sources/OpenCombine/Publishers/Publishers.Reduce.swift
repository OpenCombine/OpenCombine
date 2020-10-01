//
//  Publishers.Reduce.swift
//  
//
//  Created by Sergej Jaskiewicz on 09.10.2019.
//

extension Publisher {

    /// Applies a closure that collects each element of a stream and publishes a final
    /// result upon completion.
    ///
    /// Use `reduce(_:_:)` to collect a stream of elements and produce an accumulated
    /// value based on a closure you provide.
    ///
    /// In the following example, the `reduce(_:_:)` operator collects all the integer
    /// values it receives from its upstream publisher:
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .reduce(0, { accum, next in accum + next })
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "55"
    ///
    /// - Parameters:
    ///   - initialResult: The value that the closure receives the first time it’s called.
    ///   - nextPartialResult: A closure that produces a new value by taking
    ///     the previously-accumulated value and the next element it receives from
    ///     the upstream publisher.
    /// - Returns: A publisher that applies the closure to all received elements and
    ///   produces an accumulated value when the upstream publisher finishes.
    ///   If `reduce(_:_:)` receives an error from the upstream publisher, the operator
    ///   delivers it to the downstream subscriber, the publisher terminates and publishes
    ///   no value.
    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: @escaping (Accumulator, Output) -> Accumulator
    ) -> Publishers.Reduce<Self, Accumulator> {
        return .init(upstream: self,
                     initial: initialResult,
                     nextPartialResult: nextPartialResult)
    }

    /// Applies an error-throwing closure that collects each element of a stream and
    /// publishes a final result upon completion.
    ///
    /// Use `tryReduce(_:_:)` to collect a stream of elements and produce an accumulated
    /// value based on an error-throwing closure you provide.
    /// If the closure throws an error, the publisher fails and passes the error to its
    /// subscriber.
    ///
    /// In the example below, the publisher’s `0` element causes the `myDivide(_:_:)`
    /// function to throw an error and publish the `Double.nan` result:
    ///
    ///     struct DivisionByZeroError: Error {}
    ///     func myDivide(_ dividend: Double, _ divisor: Double) throws -> Double {
    ///         guard divisor != 0 else { throw DivisionByZeroError() }
    ///         return dividend / divisor
    ///     }
    ///
    ///     var numbers: [Double] = [5, 4, 3, 2, 1, 0]
    ///     numbers.publisher
    ///         .tryReduce(numbers.first!, { accum, next in try myDivide(accum, next) })
    ///         .catch({ _ in Just(Double.nan) })
    ///         .sink { print("\($0)") }
    ///

    /// - Parameters:
    ///   - initialResult: The value that the closure receives the first time it’s called.
    ///   - nextPartialResult: An error-throwing closure that takes
    ///     the previously-accumulated value and the next element from the upstream
    ///     publisher to produce a new value.
    ///
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
