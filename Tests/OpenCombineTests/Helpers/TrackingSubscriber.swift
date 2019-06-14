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
final class TrackingSubscriber: Subscriber, CustomStringConvertible {

    enum Event: Equatable {
        case subscription(Subscription)
        case value(Int)
        case completion(Subscribers.Completion<TestingError>)

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
                    return lhs == rhs
                default:
                    return false
                }
            default:
                return false
            }
        }
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

    var description: String {
        "\(type(of: self)): \(history)"
    }

    deinit {
        _onDeinit?()
    }
}

@available(macOS 10.15, *)
final class TrackingSubject: Subject {

    typealias Failure = TestingError

    typealias Output = Int

    enum Event: Equatable {
        case subscriber(CombineIdentifier)
        case value(Int)
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

    func send(_ value: Int) {
        history.append(.value(value))
    }

    func send(completion: Subscribers.Completion<TestingError>) {
        history.append(.completion(completion))
    }

    func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        history.append(.subscriber(subscriber.combineIdentifier))
    }
}
