//
//  TransformingInner.swift
//
//  Created by Eric Patey on 26.08.2019.
//

// This fileprivate base class provides the majority of the implementation for operators
// that perform a 1:1 transformation of `Upstream.Output`'s into `Downstream.Input`'s. It
// properly handles values and completion from `Upstream` and (via `OperatorSubscription`)
// manages `Downstream` and `Upstream` references.
//
// Operator implementations implement `Inner` classes that derive from one of the two
// internal subclasses of this base class - `NonThrowingTransformingInner` or
// `ThrowingTransformingInner`.

internal class TransformingInner<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>
{
    private final var transform: ((Upstream.Output) -> Result<Downstream.Input, Downstream.Failure>)?

    fileprivate init(
        downstream: Downstream,
        transform: @escaping (Upstream.Output) -> Result<Downstream.Input, Downstream.Failure>)
    {
        self.transform = transform
        super.init(downstream: downstream)
    }

    internal final func receive(_ input: Upstream.Output) -> Subscribers.Demand {
        guard let trans = transform else { return .none }
        switch trans(input) {
        case .success(let transformedValue):
            return downstream.receive(transformedValue)
        case .failure(let error):
            downstream.receive(completion: .failure(error))
            transform = nil
            return .none
        }
    }

    internal final func receive(completion: Subscribers.Completion<Downstream.Failure>) {
        // Strangely, Apple lets multiple .completion(.failure())'s through, but not
        // multiple .completion(.finished)'s through.
        switch completion {
        case .finished where transform == nil:
            break
        default:
            downstream?.receive(completion: completion)
        }
        transform = nil
    }
}

internal class NonThrowingTransformingInner<Upstream: Publisher, Downstream: Subscriber>
    : TransformingInner<Upstream, Downstream>,
    Subscriber
    where Upstream.Failure == Downstream.Failure
{
    internal init(downstream: Downstream,
                  transform: @escaping (Upstream.Output) -> Downstream.Input) {
        super.init(downstream: downstream, transform: catching(transform))
    }

    // Complete the base class conformance to `Subscriber`
    internal final func receive(subscription: Subscription) {
        downstream.receive(subscription: subscription)
    }
}

internal class ThrowingTransformingInner<Upstream: Publisher, Downstream: Subscriber>
    : TransformingInner<Upstream, Downstream>,
    Subscriber,
    Subscription
    where Downstream.Failure == Error
{
    typealias Failure = Upstream.Failure

    internal init(downstream: Downstream,
                  transform: @escaping (Upstream.Output) throws -> Downstream.Input) {
        super.init(downstream: downstream, transform: catching(transform))
    }

    // Conform to `Subscription`
    internal final func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }

    // Complete the base class conformance to `Subscriber`
    internal final func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    internal final func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        super.receive(completion: completion.eraseError())
    }
}
