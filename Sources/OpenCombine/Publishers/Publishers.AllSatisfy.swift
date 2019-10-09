//
//  Publishers.AllSatisfy.swift
//  
//
//  Created by Sergej Jaskiewicz on 09.10.2019.
//

extension Publisher {

    /// Publishes a single Boolean value that indicates whether all received elements pass
    /// a given predicate.
    ///
    /// When this publisher receives an element, it runs the predicate against
    /// the element. If the predicate returns `false`, the publisher produces a `false`
    /// value and finishes. If the upstream publisher finishes normally, this publisher
    /// produces a `true` value and finishes.
    /// As a `reduce`-style operator, this publisher produces at most one value.
    /// Backpressure note: Upon receiving any request greater than zero, this publisher
    /// requests unlimited elements from the upstream publisher.
    ///
    /// - Parameter predicate: A closure that evaluates each received element.
    ///   Return `true` to continue, or `false` to cancel the upstream and complete.
    /// - Returns: A publisher that publishes a Boolean value that indicates whether
    ///   all received elements pass a given predicate.
    public func allSatisfy(
        _ predicate: @escaping (Output) -> Bool
    ) -> Publishers.AllSatisfy<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Publishes a single Boolean value that indicates whether all received elements pass
    /// a given error-throwing predicate.
    ///
    /// When this publisher receives an element, it runs the predicate against
    /// the element. If the predicate returns `false`, the publisher produces a `false`
    /// value and finishes. If the upstream publisher finishes normally, this publisher
    /// produces a `true` value and finishes. If the predicate throws an error,
    /// the publisher fails, passing the error to its downstream.
    /// As a `reduce`-style operator, this publisher produces at most one value.
    /// Backpressure note: Upon receiving any request greater than zero, this publisher
    /// requests unlimited elements from the upstream publisher.
    ///
    /// - Parameter predicate:  A closure that evaluates each received element.
    ///   Return `true` to continue, or `false` to cancel the upstream and complete.
    ///   The closure may throw, in which case the publisher cancels the upstream
    ///   publisher and fails with the thrown error.
    /// - Returns: A publisher that publishes a Boolean value that indicates whether
    ///   all received elements pass a given predicate.
    public func tryAllSatisfy(
        _ predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryAllSatisfy<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {

    /// A publisher that publishes a single Boolean value that indicates whether
    /// all received elements pass a given predicate.
    public struct AllSatisfy<Upstream: Publisher>: Publisher {

        public typealias Output = Bool

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that evaluates each received element.
        ///
        ///  Return `true` to continue, or `false` to cancel the upstream and finish.
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

    /// A publisher that publishes a single Boolean value that indicates whether
    /// all received elements pass a given error-throwing predicate.
    public struct TryAllSatisfy<Upstream: Publisher>: Publisher {

        public typealias Output = Bool

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that evaluates each received element.
        ///
        /// Return `true` to continue, or `false` to cancel the upstream and complete.
        /// The closure may throw, in which case the publisher cancels the upstream
        /// publisher and fails with the thrown error.
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

extension Publishers.AllSatisfy {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Bool,
                         Upstream.Failure,
                         (Upstream.Output) -> Bool>
        where Downstream.Input == Output, Upstream.Failure == Downstream.Failure
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Upstream.Output) -> Bool) {
            super.init(downstream: downstream, initial: true, reduce: predicate)
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            if !reduce(newValue) {
                result = false
                return .finished
            }

            return .continue
        }

        override var description: String { return "AllSatisfy" }
    }
}

extension Publishers.TryAllSatisfy {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Bool,
                         Upstream.Failure,
                         (Upstream.Output) throws -> Bool>
        where Downstream.Input == Output, Downstream.Failure == Error
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Upstream.Output) throws -> Bool) {
            super.init(downstream: downstream, initial: true, reduce: predicate)
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            do {
                if try !reduce(newValue) {
                    result = false
                    return .finished
                }
            } catch {
                return .failure(error)
            }

            return .continue
        }

        override var description: String { return "TryAllSatisfy" }
    }
}
