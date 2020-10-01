//
//  Publishers.PrefixWhile.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.10.2019.
//

extension Publisher {

    /// Republishes elements while a predicate closure indicates publishing should
    /// continue.
    ///
    /// Use `prefix(while:)` to emit values while elements from the upstream publishe
    /// meet a condition you specify. The publisher finishes when the closure returns
    /// `false`.
    ///
    /// In the example below, the `prefix(while:)` operator emits values while the element
    /// it receives is less than five:
    ///
    ///     let numbers = (0...10)
    ///     numbers.publisher
    ///         .prefix { $0 < 5 }
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1 2 3 4"
    ///
    /// - Parameter predicate: A closure that takes an element as its parameter and
    ///   returns a Boolean value that indicates whether publishing should continue.
    /// - Returns: A publisher that passes through elements until the predicate indicates
    ///   publishing should finish.
    public func prefix(
        while predicate: @escaping (Output) -> Bool
    ) -> Publishers.PrefixWhile<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Republishes elements while an error-throwing predicate closure indicates
    /// publishing should continue.
    ///
    /// Use `tryPrefix(while:)` to emit values from the upstream publisher that meet
    /// a condition you specify in an error-throwing closure.
    /// The publisher finishes when the closure returns `false`. If the closure throws
    /// an error, the publisher fails with that error.
    ///
    ///     struct OutOfRangeError: Error {}
    ///
    ///     let numbers = (0...10).reversed()
    ///     cancellable = numbers.publisher
    ///         .tryPrefix {
    ///             guard $0 != 0 else { throw OutOfRangeError() }
    ///             return $0 <= numbers.max()!
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)", terminator: " ") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///         )
    ///
    ///     // Prints: "10 9 8 7 6 5 4 3 2 1 completion: failure(OutOfRangeError()) "
    ///
    /// - Parameter predicate: A closure that takes an element as its parameter and
    ///   returns a Boolean value indicating whether publishing should continue.
    /// - Returns: A publisher that passes through elements until the predicate throws or
    ///   indicates publishing should finish.
    public func tryPrefix(
        while predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryPrefixWhile<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {

    /// A publisher that republishes elements while a predicate closure indicates
    /// publishing should continue.
    public struct PrefixWhile<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that determines whether whether publishing should continue.
        public let predicate: (Upstream.Output) -> Bool

        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: predicate))
        }
    }

    /// A publisher that republishes elements while an error-throwing predicate closure
    /// indicates publishing should continue.
    public struct TryPrefixWhile<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that determines whether publishing should continue.
        public let predicate: (Upstream.Output) throws -> Bool

        public init(upstream: Upstream,
                    predicate: @escaping (Upstream.Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Output == Downstream.Input, Downstream.Failure == Error
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: predicate))
        }
    }
}

extension Publishers.PrefixWhile {
    private final class Inner<Downstream: Subscriber>
        : FilterProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Upstream.Output) -> Bool>
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        override func receive(
            newValue: Input
        ) -> PartialCompletion<Upstream.Output?, Downstream.Failure> {
            return filter(newValue) ? .continue(newValue) : .finished
        }

        override var description: String { return "PrefixWhile" }
    }
}

extension Publishers.TryPrefixWhile {
    private final class Inner<Downstream: Subscriber>
        : FilterProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Upstream.Output) throws -> Bool>
        where Downstream.Input == Upstream.Output, Downstream.Failure == Error
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        override func receive(
            newValue: Input
        ) -> PartialCompletion<Upstream.Output?, Downstream.Failure> {
            do {
                return try filter(newValue) ? .continue(newValue) : .finished
            } catch {
                return .failure(error)
            }
        }

        override var description: String { return "TryPrefixWhile" }
    }
}
