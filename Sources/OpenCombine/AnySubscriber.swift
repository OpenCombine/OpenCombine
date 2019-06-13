//
//  AnySubscriber.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A type-erasing subscriber.
///
/// Use an `AnySubscriber` to wrap an existing subscriber whose details you don’t want to expose.
/// You can also use `AnySubscriber` to create a custom subscriber by providing closures for `Subscriber`’s
/// methods, rather than implementing `Subscriber` directly.
public struct AnySubscriber<Input, Failure: Error>: Subscriber,
                                                    CustomStringConvertible,
                                                    CustomReflectable,
                                                    CustomPlaygroundDisplayConvertible {

    private let _receiveSubscription: ((Subscription) -> Void)?
    private let _receiveValue: ((Input) -> Subscribers.Demand)?
    private let _receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?
    private let _combineIdentifier: CombineIdentifier

    private let _parent: Any?

    private var _upstreamSubscription: Subscription?

    public var combineIdentifier: CombineIdentifier { _combineIdentifier }

    public var description: String {
        _parent.map(String.init(describing:)) ?? "AnySubscriber"
    }

    public var customMirror: Mirror {
        _parent.map(Mirror.init) ?? Mirror(CombineIdentifier(), children: [])
    }

    /// A custom playground description for this instance.
    public var playgroundDescription: Any { description }

    /// Creates a type-erasing subscriber to wrap an existing subscriber.
    ///
    /// - Parameter s: The subscriber to type-erase.
    public init<S: Subscriber>(_ s: S) where Input == S.Input, Failure == S.Failure {
        _receiveSubscription = s.receive(subscription:)
        _receiveValue = s.receive(_:)
        _receiveCompletion = s.receive(completion:)
        _combineIdentifier = s.combineIdentifier
        _parent = s
    }

    public init<S: Subject>(_ s: S) where Input == S.Output, Failure == S.Failure {
        _receiveValue = { s.send($0); return .unlimited }
        _receiveCompletion = s.send(completion:)
        _receiveSubscription = nil
        _combineIdentifier = CombineIdentifier(s)
        _parent = s
    }

    /// Creates a type-erasing subscriber that executes the provided closures.
    ///
    /// - Parameters:
    ///   - receiveSubscription: A closure to execute when the subscriber receives the initial subscription from
    ///     the publisher.
    ///   - receiveValue: A closure to execute when the subscriber receives a value from the publisher.
    ///   - receiveCompletion: A closure to execute when the subscriber receives a completion callback from
    ///     the publisher.
    public init(receiveSubscription: ((Subscription) -> Void)? = nil,
                receiveValue: ((Input) -> Subscribers.Demand)? = nil,
                receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil) {
        _receiveSubscription = receiveSubscription
        _receiveValue = receiveValue
        _receiveCompletion = receiveCompletion
        _combineIdentifier = CombineIdentifier()
        _parent = nil
    }

    public func receive(subscription: Subscription) {
        _receiveSubscription?(subscription)
    }

    public func receive(_ value: Input) -> Subscribers.Demand {
        _receiveValue?(value) ?? .max(0)
    }

    public func receive(completion: Subscribers.Completion<Failure>) {
        _receiveCompletion?(completion)
    }
}
