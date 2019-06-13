//
//  TrackingSubscriber.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class TrackingSubscriber: Subscriber {

    enum Event {
        case subscription(Subscription)
        case value(Int)
        case completion(Subscribers.Completion<TestingError>)
    }

    private let _any: AnySubscriber<Int, TestingError>
    private let _onDeinit: (() -> Void)?

    private(set) var history: [Event] = []

    var countSubscriptions: Int {
        history.lazy.filter {
            if case .subscription = $0 {
                return true
            } else {
                return false
            }
        }.count
    }

    var countInputs: Int {
        history.lazy.filter {
            if case .value = $0 {
                return true
            } else {
                return false
            }
        }.count
    }

    var countCompletions: Int {
        history.lazy.filter {
            if case .completion = $0 {
                return true
            } else {
                return false
            }
        }.count
    }

    init(receiveSubscription: ((Subscription) -> Void)? = nil,
         receiveValue: ((Input) -> Subscribers.Demand)? = nil,
         receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
         onDeinit: (() -> Void)? = nil) {
        _any = AnySubscriber(receiveSubscription: receiveSubscription,
                             receiveValue: receiveValue,
                             receiveCompletion: receiveCompletion)
        _onDeinit = onDeinit
    }

    func receive(subscription: Subscription) {
        history.append(.subscription(subscription))
        _any.receive(subscription: subscription)
    }

    func receive(_ input: Int) -> Subscribers.Demand {
        history.append(.value(input))
        return _any.receive(input)
    }

    func receive(completion: Subscribers.Completion<TestingError>) {
        history.append(.completion(completion))
        _any.receive(completion: completion)
    }

    deinit {
        _onDeinit?()
    }
}
