//
//  TransformingInner.swift
//
//  Created by Eric Patey on 26.08.2019.
//

internal class TransformingInner<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
    CustomStringConvertible
    where Upstream.Failure == Downstream.Failure
{
    internal let description: String
    private let shouldProxySubscription: Bool
    private var transform: ((Input) -> Result<Downstream.Input, Failure>)?

    internal init(description: String,
                  downstream: Downstream,
                  shouldProxySubscription: Bool,
                  transform: @escaping (Input)
        -> Result<Downstream.Input, Downstream.Failure>) {
        self.shouldProxySubscription = shouldProxySubscription
        self.transform = transform
        self.description = description
        super.init(downstream: downstream)
    }
}

extension TransformingInner: Subscriber {
    public typealias Input = Upstream.Output
    public typealias Failure = Upstream.Failure

    public final func receive(subscription: Subscription) {
        if shouldProxySubscription {
            upstreamSubscription = subscription
            downstream.receive(subscription: self)
        } else {
            downstream.receive(subscription: subscription)
        }
    }

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

extension TransformingInner: Subscription {
    public final func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }
}
