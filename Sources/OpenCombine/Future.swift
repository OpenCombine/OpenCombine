//
//  Future.swift
//  
//
//  Created by Max Desiatov on 24/11/2019.
//

/// A publisher that eventually produces one value and then finishes or fails.
public final class Future<Output, Failure>: Publisher where Failure: Error {

    public typealias Promise = (Result<Output, Failure>) -> Void

    private let _lock = UnfairRecursiveLock.allocate()
    private var _subscriptions: [Conduit] = []

    private var result: Result<Output, Failure>?

    public init(
        _ attemptToFulfill: @escaping (@escaping Promise) -> Void
    ) {
        attemptToFulfill { result in
            self._lock.do {
                guard self.result == nil else { return }
                self.result = result
                self._publish(result)
            }
        }
    }

    deinit {
        _lock.deallocate()
    }

    /// This function is called to attach the specified `Subscriber` to this
    /// `Publisher` by `subscribe(_:)`
    ///
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`.
    ///                   once attached it can begin to receive values.
    public func receive<Downstream: Subscriber>(
        subscriber: Downstream
    ) where Output == Downstream.Input, Failure == Downstream.Failure {
        let subscription = Conduit(parent: self,
                                   downstream: AnySubscriber(subscriber))

        _subscriptions.append(subscription)
       subscriber.receive(subscription: subscription)
    }

    private func _acknowledgeDownstreamDemand() {
        _lock.do {
            guard let result = result else { return }
            _publish(result)
        }
    }

    private func _publish(_ result: Result<Output, Failure>) {
        for subscription in self._subscriptions where !subscription._isCompleted {
            switch result {
            case let .success(output) where subscription._demand > 0:
                subscription._demand -= 1
                subscription._demand += subscription._downstream?.receive(output) ?? .none
                subscription._receive(completion: .finished)
            case let .failure(error):
                subscription._receive(completion: .failure(error))

            // nothing to do if no demand
            default: ()
            }
        }
    }
}

extension Future {

    fileprivate final class Conduit: Subscription {

        fileprivate var _parent: Future<Output, Failure>?

        fileprivate var _downstream: AnySubscriber<Output, Failure>?

        fileprivate var _demand: Subscribers.Demand = .none

        fileprivate var _isCompleted: Bool {
            return _parent == nil
        }

        fileprivate init(parent: Future<Output, Failure>,
                         downstream: AnySubscriber<Output, Failure>) {
            _parent = parent
            _downstream = downstream
        }

        fileprivate func _receive(completion: Subscribers.Completion<Failure>) {
            if !_isCompleted {
                _parent = nil
                _downstream?.receive(completion: completion)
            }
        }

        fileprivate func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            _parent?._lock.do {
                _demand += demand
            }
            _parent?._acknowledgeDownstreamDemand()
        }

        fileprivate func cancel() {
            _parent = nil
        }
    }
}

extension Future.Conduit: CustomStringConvertible {
    fileprivate var description: String { return "Future" }
}
