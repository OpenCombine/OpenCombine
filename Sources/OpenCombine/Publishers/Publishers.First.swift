//
//  Publishers.First.swift
//  
//
//  Created by Joseph Spadafora on 7/8/19.
//

extension Publisher {

    /// Publishes the first element of a stream, then finishes.
    ///
    /// If this publisher doesn’t receive any elements, it finishes without publishing.
    /// - Returns: A publisher that only publishes the first element of a stream.
    public func first() -> Publishers.First<Self> {
        return .init(upstream: self)
    }

    /// Publishes the first element of a stream to
    /// satisfy a predicate closure, then finishes.
    ///
    /// The publisher ignores all elements after the first.
    /// If this publisher doesn’t receive any elements,
    /// it finishes without publishing.
    /// - Parameter predicate: A closure that takes an element as a parameter and
    ///   returns a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the first element of a stream
    ///   that satifies the predicate.
    public func first(
        where predicate: @escaping (Output) -> Bool
    ) -> Publishers.FirstWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Publishes the first element of a stream to satisfy a
    /// throwing predicate closure, then finishes.
    ///
    /// The publisher ignores all elements after the first. If this publisher
    /// doesn’t receive any elements, it finishes without publishing. If the
    /// predicate closure throws, the publisher fails with an error.
    /// - Parameter predicate: A closure that takes an element as a parameter and
    ///   returns a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the first element of a stream
    ///   that satifies the predicate.
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
