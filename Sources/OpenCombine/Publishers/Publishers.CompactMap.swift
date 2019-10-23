//
//  Publishers.CompactMap.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.07.2019.
//

extension Publisher {

    /// Calls a closure with each received element and publishes any returned
    /// optional that has a value.
    ///
    /// - Parameter transform: A closure that receives a value and returns
    ///   an optional value.
    /// - Returns: A publisher that republishes all non-`nil` results of calling
    ///   the transform closure.
    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult?
    ) -> Publishers.CompactMap<Self, ElementOfResult> {
        return .init(upstream: self, transform: transform)
    }

    /// Calls an error-throwing closure with each received element and publishes
    /// any returned optional that has a value.
    ///
    /// If the closure throws an error, the publisher cancels the upstream and sends
    /// the thrown error to the downstream receiver as a `Failure`.
    ///
    /// - Parameter transform: an error-throwing closure that receives a value
    ///   and returns an optional value.
    /// - Returns: A publisher that republishes all non-`nil` results of calling
    ///   the `transform` closure.
    public func tryCompactMap<ElementOfResult>(
        _ transform: @escaping (Output) throws -> ElementOfResult?
    ) -> Publishers.TryCompactMap<Self, ElementOfResult> {
        return .init(upstream: self, transform: transform)
    }
}

extension Publishers.CompactMap {

    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult?
    ) -> Publishers.CompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { self.transform($0).flatMap(transform) })
    }

    public func map<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult
    ) -> Publishers.CompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { self.transform($0).map(transform) })
    }
}

extension Publishers.TryCompactMap {

    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) throws -> ElementOfResult?
    ) -> Publishers.TryCompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { try self.transform($0).flatMap(transform) })
    }
}

extension Publishers {

    /// A publisher that republishes all non-`nil` results of calling a closure
    /// with each received element.
    public struct CompactMap<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that receives values from the upstream publisher
        /// and returns optional values.
        public let transform: (Upstream.Output) -> Output?

        public init(upstream: Upstream,
                    transform: @escaping (Upstream.Output) -> Output?) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: transform))
        }
    }

    /// A publisher that republishes all non-`nil` results of calling an error-throwing
    /// closure with each received element.
    public struct TryCompactMap<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// An error-throwing closure that receives values from the upstream publisher
        /// and returns optional values.
        ///
        /// If this closure throws an error, the publisher fails.
        public let transform: (Upstream.Output) throws -> Output?

        public init(upstream: Upstream,
                    transform: @escaping (Upstream.Output) throws -> Output?) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: transform))
        }
    }
}

extension Publishers.CompactMap {
    private final class Inner<Downstream: Subscriber>
        : FilterProducer<Downstream,
                         Upstream.Output,
                         Output,
                         Upstream.Failure,
                         (Upstream.Output) -> Output?>
        where Downstream.Failure == Upstream.Failure, Downstream.Input == Output
    {
        // NOTE: This class has been audited for thread safety

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Output?, Downstream.Failure> {
            return .continue(filter(newValue))
        }

        override var description: String { return "CompactMap" }
    }
}

extension Publishers.TryCompactMap {
    private final class Inner<Downstream: Subscriber>
        : FilterProducer<Downstream,
                         Upstream.Output,
                         Output,
                         Upstream.Failure,
                         (Upstream.Output) throws -> Output?>
        where Downstream.Failure == Error, Downstream.Input == Output
    {
        // NOTE: This class has been audited for thread safety

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Output?, Error> {
            do {
                return try .continue(filter(newValue))
            } catch {
                return .failure(error)
            }
        }

        override var description: String { return "TryCompactMap" }
    }
}
