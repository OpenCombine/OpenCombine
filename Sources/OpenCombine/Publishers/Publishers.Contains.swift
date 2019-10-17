//
//  Publishers.Contains.swift
//  
//
//  Created by Sergej Jaskiewicz on 09.10.2019.
//

extension Publisher where Output: Equatable {

    /// Publishes a Boolean value upon receiving an element equal to the argument.
    ///
    /// The contains publisher consumes all received elements until the upstream publisher
    /// produces a matching element. At that point, it emits `true` and finishes normally.
    /// If the upstream finishes normally without producing a matching element,
    /// this publisher emits `false`, then finishes.
    ///
    /// - Parameter output: An element to match against.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream
    ///   publisher emits a matching value.
    public func contains(_ output: Output) -> Publishers.Contains<Self> {
        return .init(upstream: self, output: output)
    }
}

extension Publisher {

    /// Publishes a Boolean value upon receiving an element that satisfies the predicate
    /// closure.
    ///
    /// This operator consumes elements produced from the upstream publisher until
    /// the upstream publisher produces a matching element.
    ///
    /// - Parameter predicate: A closure that takes an element as its parameter and
    ///   returns a Boolean value indicating whether the element satisfies the closure’s
    ///   comparison logic.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream
    ///   publisher emits a matching value.
    public func contains(
        where predicate: @escaping (Output) -> Bool
    ) -> Publishers.ContainsWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Publishes a Boolean value upon receiving an element that satisfies
    /// the throwing predicate closure.
    ///
    /// This operator consumes elements produced from the upstream publisher until
    /// the upstream publisher produces a matching element. If the closure throws,
    /// the stream fails with an error.
    ///
    /// - Parameter predicate: A closure that takes an element as its parameter and
    ///   returns a Boolean value indicating whether the element satisfies the closure’s
    ///   comparison logic.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream
    ///   publisher emits a matching value.
    public func tryContains(
        where predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryContainsWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {

    /// A publisher that emits a Boolean value when a specified element is received from
    /// its upstream publisher.
    public struct Contains<Upstream: Publisher>: Publisher
        where Upstream.Output: Equatable
    {
        public typealias Output = Bool

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The element to scan for in the upstream publisher.
        public let output: Upstream.Output

        public init(upstream: Upstream, output: Upstream.Output) {
            self.upstream = upstream
            self.output = output
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure, Downstream.Input == Bool
        {
            upstream.subscribe(Inner(downstream: subscriber, output: output))
        }
    }

    /// A publisher that emits a Boolean value upon receiving an element that satisfies
    /// the predicate closure.
    public struct ContainsWhere<Upstream: Publisher>: Publisher {

        public typealias Output = Bool

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that determines whether the publisher should consider an element
        /// as a match.
        public let predicate: (Upstream.Output) -> Bool

        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure, Downstream.Input == Bool
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }

    /// A publisher that emits a Boolean value upon receiving an element that satisfies
    /// the throwing predicate closure.
    public struct TryContainsWhere<Upstream: Publisher>: Publisher {

        public typealias Output = Bool

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that determines whether this publisher should
        /// emit a `true` element.
        public let predicate: (Upstream.Output) throws -> Bool

        public init(upstream: Upstream,
                    predicate: @escaping (Upstream.Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Error, Downstream.Input == Bool
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }
}

extension Publishers.Contains {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream, Upstream.Output, Bool, Upstream.Failure, Void>
        where Upstream.Failure == Downstream.Failure, Downstream.Input == Bool
    {
        private let output: Upstream.Output

        fileprivate init(downstream: Downstream, output: Upstream.Output) {
            self.output = output
            super.init(downstream: downstream, initial: false, reduce: ())
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            if newValue == output {
                result = true
                return .finished
            }

            return .continue
        }

        override var description: String { return "Contains" }
    }
}

extension Publishers.Contains : Equatable where Upstream: Equatable {}

extension Publishers.ContainsWhere {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output, Bool,
                         Upstream.Failure,
                         (Upstream.Output) -> Bool>
        where Upstream.Failure == Downstream.Failure, Downstream.Input == Bool
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Upstream.Output) -> Bool) {
            super.init(downstream: downstream, initial: false, reduce: predicate)
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            if reduce(newValue) {
                result = true
                return .finished
            }

            return .continue
        }

        override var description: String { return "ContainsWhere" }
    }
}

extension Publishers.TryContainsWhere {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output, Bool,
                         Upstream.Failure,
                         (Upstream.Output) throws -> Bool>
        where Downstream.Failure == Error, Downstream.Input == Bool
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Upstream.Output) throws -> Bool) {
            super.init(downstream: downstream, initial: false, reduce: predicate)
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            do {
                if try reduce(newValue) {
                    result = true
                    return .finished
                }
            } catch {
                return .failure(error)
            }

            return .continue
        }

        override var description: String { return "TryContainsWhere" }
    }
}
