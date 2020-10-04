//
//  FilterProducer.swift
//  
//
//  Created by Sergej Jaskiewicz on 23.10.2019.
//

/// A helper class that acts like both subscriber and subscription.
///
/// Filter-like operators send an instance of their `Inner` class that is subclass
/// of this class to the upstream publisher (as subscriber) and
/// to the downstream subscriber (as subscription).
///
/// Filter-like operators include `Publishers.Filter`,
/// `Publishers.RemoveDuplicates`, `Publishers.PrefixWhile` and more.
///
/// Subclasses must override the `receive(newValue:)` and `description`.
internal class FilterProducer<Downstream: Subscriber,
                              Input,
                              Output,
                              UpstreamFailure: Error,
                              Filter>
    : CustomStringConvertible,
      CustomReflectable
    where Downstream.Input == Output
{
    // MARK: - State

    private enum State {
        case awaitingSubscription
        case connected(Subscription)
        case completed
    }

    internal final let filter: Filter

    internal final let downstream: Downstream

    private let lock = UnfairLock.allocate()

    private var state = State.awaitingSubscription

    internal init(downstream: Downstream, filter: Filter) {
        self.downstream = downstream
        self.filter = filter
    }

    deinit {
        lock.deallocate()
    }

    // MARK: - Abstract methods

    internal func receive(
        newValue: Input
    ) -> PartialCompletion<Output?, Downstream.Failure> {
        abstractMethod()
    }

    internal var description: String {
        abstractMethod()
    }

    // MARK: - CustomReflectable

    internal var customMirror: Mirror {
        let children = CollectionOfOne<Mirror.Child>(("downstream", downstream))
        return Mirror(self, children: children)
    }
}

extension FilterProducer: Subscriber {

    internal func receive(subscription: Subscription) {
        lock.lock()
        guard case .awaitingSubscription = state else {
            lock.unlock()
            subscription.cancel()
            return
        }
        state = .connected(subscription)
        lock.unlock()
        downstream.receive(subscription: self)
    }

    internal func receive(_ input: Input) -> Subscribers.Demand {
        lock.lock()
        switch state {
        case .awaitingSubscription:
            lock.unlock()
            fatalError("Invalid state: Received value before receiving subscription")
        case .completed:
            lock.unlock()
        case let .connected(subscription):
            lock.unlock()
            switch receive(newValue: input) {
            case let .continue(output?):
                return downstream.receive(output)
            case .continue(nil):
                return .max(1)
            case .finished:
                lock.lock()
                state = .completed
                lock.unlock()
                subscription.cancel()
                downstream.receive(completion: .finished)
            case let .failure(error):
                lock.lock()
                state = .completed
                lock.unlock()
                subscription.cancel()
                downstream.receive(completion: .failure(error))
            }
        }

        return .none
    }

    internal func receive(completion: Subscribers.Completion<UpstreamFailure>) {
        lock.lock()
        switch state {
        case .awaitingSubscription:
            lock.unlock()
            fatalError("Invalid state: Received completion before receiving subscription")
        case .completed:
            lock.unlock()
            return
        case .connected:
            state = .completed
            lock.unlock()
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case let .failure(failure):
                downstream.receive(completion: .failure(failure as! Downstream.Failure))
            }
        }
    }
}

extension FilterProducer: Subscription {

    internal func request(_ demand: Subscribers.Demand) {
        demand.assertNonZero()
        lock.lock()
        switch state {
        case .awaitingSubscription:
            lock.unlock()
            fatalError("Invalid state: Received request before sending subscription")
        case .completed:
            lock.unlock()
            return
        case let .connected(subscription):
            lock.unlock()
            subscription.request(demand)
        }
    }

    internal func cancel() {
        lock.lock()
        guard case let .connected(subscription) = state else {
            state = .completed
            lock.unlock()
            return
        }
        state = .completed
        lock.unlock()
        subscription.cancel()
    }
}

extension FilterProducer: CustomPlaygroundDisplayConvertible {
    internal var playgroundDescription: Any { return description }
}
