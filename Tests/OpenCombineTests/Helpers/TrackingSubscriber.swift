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

/// `TrackingSubscriber` records every event like "receiveSubscription",
/// "receiveValue" and "receiveCompletion" into its `history` property,
/// optionally executing the provided callbacks.
///
/// This is useful when testing operators that somehow transform their upstream's output.
///
/// Note that `TrackingSubscriber.Event` is equatable, but doesn't respect
/// the subscription, in other words,
/// `TrackingSubscriber.Event.subscription(Subscription.empty)`
/// is considered equal to any other subscription no matter what the subscription object
/// actually is.
@available(macOS 10.15, iOS 13.0, *)
typealias TrackingSubscriber = TrackingSubscriberBase<Int, TestingError>

/// `TrackingSubscriber` records every event like "receiveSubscription",
/// "receiveValue" and "receiveCompletion" into its `history` property,
/// optionally executing the provided callbacks.
///
/// This is useful when testing operators that somehow transform their upstream's output.
///
/// Note that `TrackingSubscriber.Event` is equatable, but doesn't respect
/// the subscription, in other words,
/// `TrackingSubscriber.Event.subscription(Subscription.empty)`
/// is considered equal to any other subscription no matter what the subscription object
/// actually is.
@available(macOS 10.15, iOS 13.0, *)
final class TrackingSubscriberBase<Value: Equatable, Failure: Error>
    : Subscriber,
      CustomStringConvertible
{

    enum Event: Equatable, CustomStringConvertible {
        case subscription(StringSubscription)
        case value(Value)
        case completion(Subscribers.Completion<Failure>)

        static func == (lhs: Event, rhs: Event) -> Bool {
            switch (lhs, rhs) {
            case let (.subscription(lhs), .subscription(rhs)):
                return lhs == rhs
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
            case .subscription(let subscription):
                return ".subscription(\"\(subscription)\")"
            case .value(let value):
                return ".value(\(value))"
            case .completion(.finished):
                return ".completion(.finished)"
            case .completion(.failure(let error)):
                return ".completion(.failure(\(error)))"
            }
        }
    }

    private let _receiveSubscription: ((Subscription) -> Void)?
    private let _receiveValue: ((Input) -> Subscribers.Demand)?
    private let _receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?
    private let _onDeinit: (() -> Void)?

    var onSubscribe: ((Subscription) -> Void)?
    var onValue: ((Input) -> Void)?
    var onFinish: (() -> Void)?
    var onFailure: ((Failure) -> Void)?
    var onDeinit: (() -> Void)?

    /// The history of subscriptions, inputs and completions of this subscriber
    private(set) var history: [Event] = []

    /// A lazy view on `history` with all events except subscriptions filtered out
    var subscriptions: LazyMapSequence<
        LazyFilterSequence<LazyMapSequence<[Event], StringSubscription?>>,
        StringSubscription
    > {
        return history.lazy.compactMap {
            if case .subscription(let s) = $0 {
                return s
            } else {
                return nil
            }
        }
    }

    /// A lazy view on `history` with all events except receiving input filtered out
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

    /// A lazy view on `history` with all events except completions filtered out
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
        history.append(.subscription(.init(subscription)))
        onSubscribe?(subscription)
        _receiveSubscription?(subscription)
    }

    func receive(_ input: Value) -> Subscribers.Demand {
        history.append(.value(input))
        onValue?(input)
        return _receiveValue?(input) ?? .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        history.append(.completion(completion))
        switch completion {
        case .failure(let error):
            onFailure?(error)
        case .finished:
            onFinish?()
        }
        _receiveCompletion?(completion)
    }

    var description: String {
        return "\(type(of: self)): \(history)"
    }

    deinit {
        onDeinit?()
        _onDeinit?()
    }
}

@available(macOS 10.15, iOS 13.0, *)
typealias TrackingSubject<Output: Equatable> = TrackingSubjectBase<Output, TestingError>

@available(macOS 10.15, iOS 13.0, *)
final class TrackingSubjectBase<Output: Equatable, Failure: Error>
    : Subject,
      CustomStringConvertible
{
    enum Event: Equatable, CustomStringConvertible {
        case subscriber
        case subscription(StringSubscription)
        case value(Output)
        case completion(Subscribers.Completion<Failure>)

        static func == (lhs: Event, rhs: Event) -> Bool {
            switch (lhs, rhs) {
            case (.subscriber, .subscriber):
                return true
            case let (.subscription(lhs), .subscription(rhs)):
                return lhs == rhs
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
            case .subscriber:
                return ".subscriber"
            case .subscription(let description):
                return ".subscription(\"\(description)\")"
            case .value(let value):
                return ".value(\(value))"
            case .completion(.finished):
                return ".completion(.finished)"
            case .completion(.failure(let error)):
                return ".completion(.failure(\(error))"
            }
        }
    }

    private let _passthrough = PassthroughSubject<Output, Failure>()
    private(set) var history: [Event] = []
    private let _receiveSubscriber: ((CustomCombineIdentifierConvertible) -> Void)?
    private let _onDeinit: (() -> Void)?

    init(receiveSubscriber: ((CustomCombineIdentifierConvertible) -> Void)? = nil,
         onDeinit: (() -> Void)? = nil) {
        _receiveSubscriber = receiveSubscriber
        _onDeinit = onDeinit
    }

    deinit {
        _onDeinit?()
    }

    func send(subscription: Subscription) {
        history.append(.subscription(.subscription(subscription)))
        _passthrough.send(subscription: subscription)
    }

    func send(_ value: Output) {
        history.append(.value(value))
        _passthrough.send(value)
    }

    func send(completion: Subscribers.Completion<Failure>) {
        history.append(.completion(completion))
        _passthrough.send(completion: completion)
    }

    func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Failure == Downstream.Failure, Output == Downstream.Input
    {
        _receiveSubscriber?(subscriber)
        history.append(.subscriber)
        _passthrough.subscribe(subscriber)
    }

    var description: String { return "TrackingSubject" }
}

@available(macOS 10.15, iOS 13.0, *)
enum StringSubscription: Subscription,
                         CustomStringConvertible,
                         ExpressibleByStringLiteral {

    case string(String)
    case subscription(Subscription)

    init(_ subscription: Subscription) {
        self = .subscription(subscription)
    }

    init(stringLiteral value: String) {
        self = .string(value)
    }

    var description: String {
        switch self {
        case .string(let string):
            return string
        case .subscription(let subscription):
            return String(describing: subscription)
        }
    }

    func request(_ demand: Subscribers.Demand) {
        underlying?.request(demand)
    }

    var combineIdentifier: CombineIdentifier {
        switch self {
        case .subscription(let subscription):
            return subscription.combineIdentifier
        case .string:
            fatalError("String has no combineIdentifier")
        }
    }

    func cancel() {
        underlying?.cancel()
    }

    var underlying: Subscription? {
        switch self {
        case .string:
            return nil
        case .subscription(let underlying):
            return underlying
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
extension StringSubscription: Equatable {
    static func == (lhs: StringSubscription, rhs: StringSubscription) -> Bool {
        return lhs.description == rhs.description
    }
}
