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
typealias TrackingSubscriber = TrackingSubscriberBase<Int, TestingError>

@available(macOS 10.15, *)
final class TrackingSubscriberBase<Value: Equatable, Failure: Error>: Subscriber, CustomStringConvertible {

    enum Event: Equatable, CustomStringConvertible {
        case subscription(Subscription)
        case value(Value)
        case completion(Subscribers.Completion<Failure>)

        static func == (lhs: Event, rhs: Event) -> Bool {
            switch (lhs, rhs) {
            case (.subscription, .subscription):
                return true
            case let (.value(lhs), .value(rhs)):
                return lhs == rhs
            case let (.completion(lhs), .completion(rhs)):
                switch (lhs, rhs) {
                case (.finished, .finished):
                    return true
                case let (.failure(lhs), .failure(rhs)):
                    return (lhs as? TestingError) == (rhs as? TestingError)
                default:
                    return false
                }
            default:
                return false
            }
        }

        var description: String {
            switch self {
            case .subscription:
                return "subscription"
            case .value(let value):
                return "value(\(value))"
            case .completion(.finished):
                return "finished"
            case .completion(.failure(let error)):
                return "failure(\(error))"
            }
        }
    }

    private let _receiveSubscription: ((Subscription) -> Void)?
    private let _receiveValue: ((Input) -> Subscribers.Demand)?
    private let _receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?
    private let _onDeinit: (() -> Void)?

    private(set) var history: [Event] = []

    var subscriptions: LazyMapSequence<
        LazyFilterSequence<LazyMapSequence<[Event], Subscription?>>, Subscription
    > {
        return history.lazy.compactMap {
            if case .subscription(let s) = $0 {
                return s
            } else {
                return nil
            }
        }
    }

    var inputs: LazyMapSequence<
        LazyFilterSequence<LazyMapSequence<[Event], Value?>>, Value
    > {
        return history.lazy.compactMap {
            if case .value(let v) = $0 {
                return v
            } else {
                return nil
            }
        }
    }

    var completions: LazyMapSequence<
        LazyFilterSequence<
            LazyMapSequence<[Event], Subscribers.Completion<Failure>?>
        >,
        Subscribers.Completion<Failure>
    > {
        return history.lazy.compactMap {
            if case .completion(let c) = $0 {
                return c
            } else {
                return nil
            }
        }
    }

    init(receiveSubscription: ((Subscription) -> Void)? = nil,
         receiveValue: ((Input) -> Subscribers.Demand)? = nil,
         receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
         onDeinit: (() -> Void)? = nil) {
        _receiveSubscription = receiveSubscription
        _receiveValue = receiveValue
        _receiveCompletion = receiveCompletion
        _onDeinit = onDeinit
    }

    func receive(subscription: Subscription) {
        history.append(.subscription(subscription))
        _receiveSubscription?(subscription)
    }

    func receive(_ input: Value) -> Subscribers.Demand {
        history.append(.value(input))
        return _receiveValue?(input) ?? .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        history.append(.completion(completion))
        _receiveCompletion?(completion)
    }

    var description: String {
        return "\(type(of: self)): \(history)"
    }

    deinit {
        _onDeinit?()
    }
}

@available(macOS 10.15, *)
final class TrackingSubject<Value: Equatable>: Subject {

    typealias Failure = TestingError

    typealias Output = Value

    enum Event: Equatable {
        case subscriber(CombineIdentifier)
        case value(Value)
        case completion(Subscribers.Completion<TestingError>)

        static func == (lhs: Event, rhs: Event) -> Bool {
            switch (lhs, rhs) {
            case let (.subscriber(lhs), .subscriber(rhs)):
                return lhs == rhs
            case let (.value(lhs), .value(rhs)):
                return lhs == rhs
            case let (.completion(lhs), .completion(rhs)):
                switch (lhs, rhs) {
                case (.finished, .finished):
                    return true
                case let (.failure(lhs), .failure(rhs)):
                    return lhs == rhs
                default:
                    return false
                }
            default:
                return false
            }
        }
    }

    private(set) var history: [Event] = []

    func send(_ value: Value) {
        history.append(.value(value))
    }

    func send(completion: Subscribers.Completion<TestingError>) {
        history.append(.completion(completion))
    }

    func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        history.append(.subscriber(subscriber.combineIdentifier))
    }
}
