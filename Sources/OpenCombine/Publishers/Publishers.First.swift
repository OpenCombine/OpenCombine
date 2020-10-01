//
//  Publishers.First.swift
//  
//
//  Created by Joseph Spadafora on 7/8/19.
//

extension Publisher {

    /// Publishes the first element of a stream, then finishes.
    ///
    /// Use `first()` to publish just the first element from an upstream publisher, then
    /// finish normally. The `first()` operator requests `Subscribers.Demand.unlimited`
    /// from its upstream as soon as downstream requests at least one element.
    /// If the upstream completes before `first()` receives any elements, it completes
    /// without emitting any values.
    ///
    /// In this example, the `first()` publisher republishes the first element received
    /// from the sequence publisher, `-10`, then finishes normally.
    ///
    ///     let numbers = (-10...10)
    ///     cancellable = numbers.publisher
    ///         .first()
    ///         .sink { print("\($0)") }
    ///
    ///     // Print: "-10"
    ///
    /// - Returns: A publisher that only publishes the first element of a stream.
    public func first() -> Publishers.First<Self> {
        return .init(upstream: self)
    }

    /// Publishes the first element of a stream to satisfy a predicate closure, then
    /// finishes normally.
    ///
    /// Use `first(where:)` to republish only the first element of a stream that satisfies
    /// a closure you specify. The publisher ignores all elements after the first element
    /// that satisfies the closure and finishes normally.
    /// If this publisher doesn’t receive any elements, it finishes without publishing.
    ///
    /// In the example below, the provided closure causes the `Publishers.FirstWhere`
    /// publisher to republish the first received element that’s greater than `0`,
    /// then finishes normally.
    ///
    ///     let numbers = (-10...10)
    ///     cancellable = numbers.publisher
    ///         .first { $0 > 0 }
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "1"
    ///

    /// - Parameter predicate: A closure that takes an element as a parameter and returns
    ///   a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the first element of a stream that
    ///   satisfies the predicate.
    public func first(
        where predicate: @escaping (Output) -> Bool
    ) -> Publishers.FirstWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Publishes the first element of a stream to satisfy a throwing predicate closure,
    /// then finishes normally.
    ///
    /// Use `tryFirst(where:)` when you need to republish only the first element of
    /// a stream that satisfies an error-throwing closure you specify.
    /// The publisher ignores all elements after the first. If this publisher doesn’t
    /// receive any elements, it finishes without publishing. If the predicate closure
    /// throws an error, the publisher fails.
    ///
    /// In the example below, a range publisher emits the first element in the range then
    /// finishes normally:
    ///
    ///     let numberRange: ClosedRange<Int> = (-1...50)
    ///     numberRange.publisher
    ///         .tryFirst {
    ///             guard $0 < 99 else {throw RangeError()}
    ///             return true
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)", terminator: " ") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///          )
    ///
    ///     // Prints: "-1 completion: finished"
    ///     // If instead the number range were ClosedRange<Int> = (100...200),
    ///     // the tryFirst operator would terminate publishing with a RangeError.
    ///

    /// - Parameter predicate: A closure that takes an element as a parameter and returns
    ///   a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the first element of a stream that
    /// satisfies the predicate.
    public func tryFirst(
        where predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFirstWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {

    /// A publisher that publishes the first element of a stream, then finishes.
    public struct First<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber))
        }
    }

    /// A publisher that only publishes the first element of a
    /// stream to satisfy a predicate closure.
    public struct FirstWhere<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that determines whether to publish an element.
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

    /// A publisher that only publishes the first element of a stream
    /// to satisfy a throwing predicate closure.
    public struct TryFirstWhere<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that determines whether to publish an element.
        public let predicate: (Output) throws -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }
}

extension Publishers.First: Equatable where Upstream: Equatable {}

extension Publishers.First {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         Void>
        where Upstream.Output == Downstream.Input,
              Upstream.Failure == Downstream.Failure
    {
        fileprivate init(downstream: Downstream) {
            super.init(downstream: downstream, initial: nil, reduce: ())
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            result = newValue
            return .finished
        }

        override var description: String { return "First" }
    }
}

extension Publishers.FirstWhere {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream, Output, Output, Failure, (Output) -> Bool>
        where Upstream.Output == Downstream.Input,
              Upstream.Failure == Downstream.Failure
    {
        fileprivate init(downstream: Downstream, predicate: @escaping (Output) -> Bool) {
            super.init(downstream: downstream, initial: nil, reduce: predicate)
        }

        override func receive(
            newValue: Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            if reduce(newValue) {
                result = newValue
                return .finished
            } else {
                return .continue
            }
        }

        override var description: String { return "TryFirst" }
    }
}

extension Publishers.TryFirstWhere {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Output,
                         Output,
                         Upstream.Failure,
                         (Output) throws -> Bool>
        where Upstream.Output == Downstream.Input, Downstream.Failure == Error
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Output) throws -> Bool) {
            super.init(downstream: downstream, initial: nil, reduce: predicate)
        }

        override func receive(
            newValue: Output
        ) -> PartialCompletion<Void, Error> {
            do {
                if try reduce(newValue) {
                    result = newValue
                    return .finished
                } else {
                    return .continue
                }
            } catch {
                return .failure(error)
            }
        }

        override var description: String { return "TryFirstWhere" }
    }
}
