//
//  Publishers.ReplaceError.swift
//  OpenCombine
//
//  Created by Bogdan Vlad on 8/29/19.
//

import Foundation

extension Publishers {
    /// A publisher that replaces any errors in the stream with a provided element.
    public struct ReplaceError<Upstream> : Publisher where Upstream : Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Never

        /// The element with which to replace errors from the upstream publisher.
        public let output: Upstream.Output

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream, output: Publishers.ReplaceError<Upstream>.Output) {
            self.upstream = upstream
            self.output = output
        }

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<SubscriberType>(subscriber: SubscriberType) where SubscriberType : Subscriber, Upstream.Output == SubscriberType.Input, SubscriberType.Failure == Publishers.ReplaceError<Upstream>.Failure {
            let replaceErrorSubscriber = _ReplaceError<Upstream, SubscriberType>(downstream: subscriber, output: output)
            upstream.subscribe(replaceErrorSubscriber)
        }
    }
}

extension Publisher {
        /// Replaces any errors in the stream with the provided element.
    ///
    /// If the upstream publisher fails with an error, this publisher emits the provided element, then finishes normally.
    /// - Parameter output: An element to emit when the upstream publisher fails.
    /// - Returns: A publisher that replaces an error from the upstream publisher with the provided output element.
    public func replaceError(with output: Self.Output) -> Publishers.ReplaceError<Self> {
        return Publishers.ReplaceError(upstream: self, output: output)
    }
}

private final class _ReplaceError<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscriber,
      CustomStringConvertible,
      Subscription
    where Upstream.Output == Downstream.Input
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure

    var hasAnyDownstreamDemand: Bool = false
    var hasFailed: Bool = false
    var description: String { return "ReplaceError" }

    private let output: Downstream.Input

    init(downstream: Downstream,
         output: Downstream.Input) {
        self.output = output
        super.init(downstream: downstream)
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard hasFailed == false else {
            _ = downstream.receive(output)
            downstream?.receive(completion: .finished)
            return
        }

        hasAnyDownstreamDemand = true

        upstreamSubscription?.request(demand)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        return downstream.receive(input)
    }

    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        switch completion {
        case .finished:
            downstream.receive(completion: .finished)
        case .failure:
            hasFailed = true

            // If there was no demand from downstream,
            // ReplaceError does not forward the value that replaces the error until it is requested.
            if hasAnyDownstreamDemand {
                _ = downstream.receive(output)
                downstream?.receive(completion: .finished)
            }
        }
    }

    override func cancel() {
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
    }
}
