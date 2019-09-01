//
//  Publishers.ContainsWhere.swift
//  CYaml
//
//  Created by Bogdan Vlad on 9/1/19.
//

extension Publishers {

    /// A publisher that emits a Boolean value upon receiving an element that satisfies the predicate closure.
    public struct ContainsWhere<Upstream> : Publisher where Upstream : Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Bool

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that determines whether the publisher should consider an element as a match.
        public let predicate: (Upstream.Output) -> Bool

        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) {
            
        }

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Failure == S.Failure, S.Input == Publishers.ContainsWhere<Upstream>.Output {
            
        }
    }

    /// A publisher that emits a Boolean value upon receiving an element that satisfies the throwing predicate closure.
    public struct TryContainsWhere<Upstream> : Publisher where Upstream : Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Bool

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that determines whether this publisher should emit a `true` element.
        public let predicate: (Upstream.Output) throws -> Bool

        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) throws -> Bool) {
            
        }

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Publishers.TryContainsWhere<Upstream>.Failure, S.Input == Publishers.TryContainsWhere<Upstream>.Output {
            
        }
    }
}

extension Publisher {

    /// Publishes a Boolean value upon receiving an element that satisfies the predicate closure.
    ///
    /// This operator consumes elements produced from the upstream publisher until the upstream publisher produces a matching element.
    /// - Parameter predicate: A closure that takes an element as its parameter and returns a Boolean value indicating whether the element satisfies the closure’s comparison logic.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream  publisher emits a matching value.
    public func contains(where predicate: @escaping (Self.Output) -> Bool) -> Publishers.ContainsWhere<Self> {
        
    }

    /// Publishes a Boolean value upon receiving an element that satisfies the throwing predicate closure.
    ///
    /// This operator consumes elements produced from the upstream publisher until the upstream publisher produces a matching element. If the closure throws, the stream fails with an error.
    /// - Parameter predicate: A closure that takes an element as its parameter and returns a Boolean value indicating whether the element satisfies the closure’s comparison logic.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream publisher emits a matching value.
    public func tryContains(where predicate: @escaping (Self.Output) throws -> Bool) -> Publishers.TryContainsWhere<Self> {
        
    }
}
