//
//  Publishers.Contains.swift
//  CYaml
//
//  Created by Bogdan Vlad on 9/1/19.
//

extension Publishers {

    /// A publisher that emits a Boolean value when a specified element is received from its upstream publisher.
    public struct Contains<Upstream> : Publisher where Upstream : Publisher, Upstream.Output : Equatable {

        /// The kind of values published by this publisher.
        public typealias Output = Bool

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The element to scan for in the upstream publisher.
        public let output: Upstream.Output

        public init(upstream: Upstream, output: Upstream.Output) {
            self.upstream = upstream
            self.output = output
        }

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Failure == S.Failure, S.Input == Publishers.Contains<Upstream>.Output {
            
        }
    }
}

extension Publisher where Self.Output : Equatable {

    /// Publishes a Boolean value upon receiving an element equal to the argument.
    ///
    /// The contains publisher consumes all received elements until the upstream publisher produces a matching element. At that point, it emits `true` and finishes normally. If the upstream finishes normally without producing a matching element, this publisher emits `false`, then finishes.
    /// - Parameter output: An element to match against.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream publisher emits a matching value.
    public func contains(_ output: Self.Output) -> Publishers.Contains<Self> {
        return Publishers.Contains(upstream: self, output: output)
    }
}
