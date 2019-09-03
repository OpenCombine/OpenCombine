//
//  TransformingInner.swift
//
//  Created by Eric Patey on 26.08.2019.
//

internal class TransformingInnerBase<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>
    where Upstream.Failure == Downstream.Failure
{
    private var transform: ((Input) -> Result<Downstream.Input, Failure>)?

    internal init(downstream: Downstream,
                  transform: @escaping (Input)
        -> Result<Downstream.Input, Downstream.Failure>) {
        self.transform = transform
        super.init(downstream: downstream)
    }
}

// This extension mostly provides an implementation of Subscriber. Subclassess must
// provide an implementation of `.receive(subscription:)`
extension TransformingInnerBase {
    public typealias Input = Upstream.Output
    public typealias Failure = Upstream.Failure

    public final func receive(_ input: Upstream.Output) -> Subscribers.Demand {
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

    public final func receive(completion: Subscribers.Completion<Upstream.Failure>) {
        // Strangely, Apple lets multiple .completion(.failure())'s through,
        // but not multiple .completion(.finished)'s through.
        switch completion {
        case .finished where transform == nil:
            break
        default:
            downstream?.receive(completion: completion)
        }
        transform = nil
    }
}

extension TransformingInnerBase: Subscription {
    public final func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }
}

internal class TransformingInner<Upstream: Publisher, Downstream: Subscriber>
    : TransformingInnerBase<Upstream, Downstream>,
    Subscriber
    where Upstream.Failure == Downstream.Failure
{
    public final func receive(subscription: Subscription) {
        downstream.receive(subscription: subscription)
    }
}

internal class ThrowingTransformingInner<Upstream: Publisher, Downstream: Subscriber>
    : TransformingInnerBase<Upstream, Downstream>,
    Subscriber
    where Upstream.Failure == Downstream.Failure
{
    public final func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }
}
