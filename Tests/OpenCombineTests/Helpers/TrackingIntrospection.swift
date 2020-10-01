//
//  TrackingIntrospection.swift
//  OpenCombineTests
//
//  Created by Sergej Jaskiewicz on 30.09.2020.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 11.0, iOS 14.0, *)
typealias TrackingIntrospection = TrackingIntrospectionBase<Int, TestingError>

@available(macOS 11.0, iOS 14.0, *)
internal final class TrackingIntrospectionBase<Value: Equatable,
                                               Failure: Error & Equatable>
    : _Introspection
{
    internal enum Event: Equatable {
        case publisherWillReceiveSubscriber(StringOrPublisher, StringOrSubscriber)
        case publisherDidReceiveSubscriber(StringOrPublisher, StringOrSubscriber)
        case subscriberWillReceiveSubscription(StringOrSubscriber, StringSubscription)
        case subscriberDidReceiveSubscription(StringOrSubscriber, StringSubscription)
        case subscriberWillReceiveInput(StringOrSubscriber, Value)
        case subscriberDidReceiveInput(StringOrSubscriber, Value, Subscribers.Demand)
        case subscriberWillReceiveCompletion(StringOrSubscriber,
                                             Subscribers.Completion<Failure>)
        case subscriberDidReceiveCompletion(StringOrSubscriber,
                                            Subscribers.Completion<Failure>)
        case willRequestDemand(StringSubscription, Subscribers.Demand)
        case didRequestDemand(StringSubscription, Subscribers.Demand)
        case willCancel(StringSubscription)
        case didCancel(StringSubscription)
    }

    private(set) var history = [Event]()

    func willReceive<Upstream: Publisher, Downstream: Subscriber>(publisher: Upstream,
                                                                  subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input
    {
        history
            .append(.publisherWillReceiveSubscriber(.init(publisher), .init(subscriber)))
    }

    func didReceive<Upstream: Publisher, Downstream: Subscriber>(publisher: Upstream,
                                                                 subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input
    {
        history
            .append(.publisherDidReceiveSubscriber(.init(publisher), .init(subscriber)))
    }

    func willReceive<Downstream: Subscriber>(subscriber: Downstream,
                                             subscription: Subscription) {
        history.append(
            .subscriberWillReceiveSubscription(.init(subscriber), .init(subscription))
        )
    }

    func didReceive<Downstream: Subscriber>(subscriber: Downstream,
                                            subscription: Subscription) {
        history.append(
            .subscriberDidReceiveSubscription(.init(subscriber), .init(subscription))
        )
    }

    func willReceive<Downstream: Subscriber>(subscriber: Downstream,
                                             input: Downstream.Input) {
        guard let input = input as? Value else {
            XCTFail("Unexpected input type")
            return
        }
        history.append(.subscriberWillReceiveInput(.init(subscriber), input))
    }

    func didReceive<Downstream: Subscriber>(subscriber: Downstream,
                                            input: Downstream.Input,
                                            resultingDemand: Subscribers.Demand) {
        guard let input = input as? Value else {
            XCTFail("Unexpected input type")
            return
        }
        history
            .append(.subscriberDidReceiveInput(.init(subscriber), input, resultingDemand))
    }

    func willReceive<Downstream: Subscriber>(
        subscriber: Downstream,
        completion: Subscribers.Completion<Downstream.Failure>
    ) {
        guard let completion = completion.castFailure(to: Failure.self) else {
            XCTFail("Unexpected input type")
            return
        }
        history.append(
            .subscriberWillReceiveCompletion(.init(subscriber), completion)
        )
    }

    func didReceive<Downstream: Subscriber>(
        subscriber: Downstream,
        completion: Subscribers.Completion<Downstream.Failure>
    ) {
        guard let completion = completion.castFailure(to: Failure.self) else {
            XCTFail("Unexpected input type")
            return
        }
        history.append(
            .subscriberDidReceiveCompletion(.init(subscriber), completion)
        )
    }

    func willRequest(subscription: Subscription, _ demand: Subscribers.Demand) {
        history.append(.willRequestDemand(.init(subscription), demand))
    }

    func didRequest(subscription: Subscription, _ demand: Subscribers.Demand) {
        history.append(.didRequestDemand(.init(subscription), demand))
    }

    func willCancel(subscription: Subscription) {
        history.append(.willCancel(.init(subscription)))
    }

    func didCancel(subscription: Subscription) {
        history.append(.didCancel(.init(subscription)))
    }
}

@available(macOS 11.0, iOS 14.0, *)
extension TrackingIntrospectionBase.Event: CustomStringConvertible {
    var description: String {
        switch self {
        case let .publisherWillReceiveSubscriber(publisher, subscriber):
            return ".publisherWillReceiveSubscriber(\"\(publisher)\", \"\(subscriber)\")"
        case let .publisherDidReceiveSubscriber(publisher, subscriber):
            return ".publisherDidReceiveSubscriber(\"\(publisher)\", \"\(subscriber)\")"
        case let .subscriberWillReceiveSubscription(subscriber, subscription):
            return """
            .subscriberWillReceiveSubscription(\"\(subscriber)\", \"\(subscription)\")
            """
        case let .subscriberDidReceiveSubscription(subscriber, subscription):
            return """
            .subscriberDidReceiveSubscription(\"\(subscriber)\", \"\(subscription)\")
            """
        case let .subscriberWillReceiveInput(subscriber, input):
            var debugDescription = ""
            debugPrint(input, terminator: "", to: &debugDescription)
            return ".subscriberWillReceiveInput(\"\(subscriber)\", \(debugDescription))"
        case let .subscriberDidReceiveInput(subscriber, input, demand):
            var debugDescription = ""
            debugPrint(input, terminator: "", to: &debugDescription)
            return """
            .subscriberDidReceiveInput(\"\(subscriber)\", \(debugDescription), .\(demand))
            """
        case let .subscriberWillReceiveCompletion(subscriber, .finished):
            return ".subscriberWillReceiveCompletion(\"\(subscriber)\", .finished)"
        case let .subscriberWillReceiveCompletion(subscriber, .failure(error)):
            var debugDescription = ""
            debugPrint(error, terminator: "", to: &debugDescription)
            return """
            .subscriberWillReceiveCompletion(\"\(subscriber)\", \
            .failure(\(debugDescription)))
            """
        case let .subscriberDidReceiveCompletion(subscriber, .finished):
            return ".subscriberDidReceiveCompletion(\"\(subscriber)\", .finished)"
        case let .subscriberDidReceiveCompletion(subscriber, .failure(error)):
            var debugDescription = ""
            debugPrint(error, terminator: "", to: &debugDescription)
            return """
            .subscriberDidReceiveCompletion(\"\(subscriber)\", \
            .failure(\(debugDescription)))
            """
        case let .willRequestDemand(subscription, demand):
            return ".willRequestDemand(\"\(subscription)\", .\(demand))"
        case let .didRequestDemand(subscription, demand):
            return ".didRequestDemand(\"\(subscription)\", .\(demand))"
        case let .willCancel(subscription):
            return ".willCancel(\"\(subscription)\")"
        case let .didCancel(subscription):
            return ".didCancel(\"\(subscription)\")"
        }
    }
}

@available(macOS 11.0, iOS 14.0, *)
extension _Introspection {
    internal func temporarilyEnable(_ body: () throws -> Void) rethrows {
        enable()
        defer { disable() }
        try body()
    }
}

@available(macOS 10.15, iOS 13.0, *)
extension Subscribers.Completion {
    func castFailure<Target: Error>(
        to target: Target.Type
    ) -> Subscribers.Completion<Target>? {
        guard Failure.self == Target.self else {
            return nil
        }
        switch self {
        case .finished:
            return .finished
        case .failure(let error):
            return .failure(error as! Target)
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
struct StringOrPublisher: CustomStringConvertible,
                          ExpressibleByStringLiteral {

    private enum Storage {
        case string(String)
        case publisher(Any)
        case anything
    }

    private var storage: Storage

    private init(_ storage: Storage) {
        self.storage = storage
    }

    init<Pub: Publisher>(_ publisher: Pub) {
        self.init(.publisher(publisher))
    }

    init(stringLiteral value: String) {
        self.init(.string(value))
    }

    static let anything = StringOrPublisher(.anything)

    var description: String {
        switch storage {
        case .string(let string):
            return string
        case .publisher(let publisher):
            return String(describing: publisher)
        case .anything:
            return "<anything>"
        }
    }

    var underlying: Any? {
        switch storage {
        case .string, .anything:
            return nil
        case .publisher(let publisher):
            return publisher
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
extension StringOrPublisher: Equatable {
    static func == (lhs: StringOrPublisher, rhs: StringOrPublisher) -> Bool {
        switch (lhs.storage, rhs.storage) {
        case (.anything, _), (_, .anything):
            return true
        default:
            return lhs.description == rhs.description
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
struct StringOrSubscriber: CustomStringConvertible,
                           ExpressibleByStringLiteral {

    private enum Storage {
        case string(String)
        case subscriber(CustomCombineIdentifierConvertible)
    }

    private var storage: Storage

    init<Pub: Subscriber>(_ subscriber: Pub) {
        storage = .subscriber(subscriber)
    }

    init(stringLiteral value: String) {
        storage = .string(value)
    }

    var description: String {
        switch storage {
        case .string(let string):
            return string
        case .subscriber(let subscriber):
            return String(describing: subscriber)
        }
    }

    var underlying: Any? {
        switch storage {
        case .string:
            return nil
        case .subscriber(let subscriber):
            return subscriber
        }
    }
}

@available(macOS 10.15, iOS 13.0, *)
extension StringOrSubscriber: Equatable {
    static func == (lhs: StringOrSubscriber, rhs: StringOrSubscriber) -> Bool {
        switch (lhs.storage, rhs.storage) {
        case let (.subscriber(lhsSubscriber), .subscriber(rhsSubscriber)):
            return lhsSubscriber.combineIdentifier == rhsSubscriber.combineIdentifier
        default:
            return lhs.description == rhs.description
        }
    }
}
