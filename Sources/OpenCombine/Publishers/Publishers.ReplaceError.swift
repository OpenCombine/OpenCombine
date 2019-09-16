//
//  Publishers.ReplaceError.swift
//  OpenCombine
//
//  Created by Bogdan Vlad on 8/29/19.
//

extension Publisher {
    /// Replaces any errors in the stream with the provided element.
    ///
    /// If the upstream publisher fails with an error, this publisher emits the provided
    /// element, then finishes normally.
    /// - Parameter output: An element to emit when the upstream publisher fails.
    /// - Returns: A publisher that replaces an error from the upstream publisher with
    ///            the provided output element.
    public func replaceError(with output: Output) -> Publishers.ReplaceError<Self> {
        return .init(upstream: self, output: output)
    }
}

extension Publishers {
    /// A publisher that replaces any errors in the stream with a provided element.
    public struct ReplaceError<Upstream: Publisher>: Publisher {

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

        public init(upstream: Upstream,
                    output: Output) {
            self.upstream = upstream
            self.output = output
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Output == Downstream.Input,
                  Downstream.Failure == Failure
        {
            let replaceErrorSubscriber = _ReplaceError<Upstream, Downstream>(
                downstream: subscriber,
                output: output
            )
            upstream.subscribe(replaceErrorSubscriber)
        }
    }
}

extension Publishers.ReplaceError: Equatable
    where Upstream: Equatable, Upstream.Output: Equatable
{}

private final class _ReplaceError<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscriber,
      CustomStringConvertible,
      Subscription
    where Upstream.Output == Downstream.Input
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure

    var downstreamDemandCounter: Subscribers.Demand = .none
    var hasFailed: Bool = false
    var description: String { return "ReplaceError" }

    private let output: Downstream.Input

    init(downstream: Downstream,
         output: Downstream.Input) {
        self.output = output
        super.init(downstream: downstream)
    }

    func request(_ demand: Subscribers.Demand) {
        if hasFailed {
            _ = downstream.receive(output)
            downstream?.receive(completion: .finished)
        } else {
            downstreamDemandCounter += demand
            upstreamSubscription?.request(demand)
        }
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        downstreamDemandCounter -= 1

        let demand = downstream.receive(input)
        downstreamDemandCounter += demand

        return demand
    }

    func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        switch completion {
        case .finished:
            downstream.receive(completion: .finished)
        case .failure:
            hasFailed = true

            // If there was no demand from downstream,
            // ReplaceError does not forward the value that
            // replaces the error until it is requested.
            if downstreamDemandCounter > 0 {
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
