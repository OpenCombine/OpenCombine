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
                                                    CustomPlaygroundDisplayConvertible
{
    private let _box: SubscriberBoxBase<Input, Failure>

    public let combineIdentifier: CombineIdentifier

    public var description: String { return _box.description }

    public var customMirror: Mirror { return _box.customMirror }

    /// A custom playground description for this instance.
    public var playgroundDescription: Any { return description }

    /// Creates a type-erasing subscriber to wrap an existing subscriber.
    ///
    /// - Parameter s: The subscriber to type-erase.
    public init<S: Subscriber>(_ s: S) where Input == S.Input, Failure == S.Failure {
        _box = SubscriberBox(base: s)
        combineIdentifier = s.combineIdentifier
    }

    public init<S: Subject>(_ s: S) where Input == S.Output, Failure == S.Failure {
        _box = SubjectSubscriber(s)
        combineIdentifier = CombineIdentifier(_box)
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
        _box = ClosureBasedSubscriber(receiveSubscription: receiveSubscription,
                                      receiveValue: receiveValue,
                                      receiveCompletion: receiveCompletion)
        combineIdentifier = CombineIdentifier()
    }

    public func receive(subscription: Subscription) {
        _box.receive(subscription: subscription)
    }

    public func receive(_ value: Input) -> Subscribers.Demand {
        return _box.receive(value)
    }

    public func receive(completion: Subscribers.Completion<Failure>) {
        _box.receive(completion: completion)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying publisher.
internal class SubscriberBoxBase<Input, Failure: Error>: Subscriber,
                                                         CustomStringConvertible,
                                                         CustomReflectable {

    func receive(subscription: Subscription) {
        fatalError()
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        fatalError()
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        fatalError()
    }

    var description: String { return "AnySubscriber" }

    var customMirror: Mirror {
        return Mirror(combineIdentifier, children: EmptyCollection())
    }
}

internal final class SubscriberBox<S: Subscriber>: SubscriberBoxBase<S.Input, S.Failure> {

    private let base: S

    init(base: S) {
        self.base = base
    }

    override func receive(subscription: Subscription) {
        base.receive(subscription: subscription)
    }

    override func receive(_ input: Input) -> Subscribers.Demand {
        return base.receive(input)
    }

    override func receive(completion: Subscribers.Completion<Failure>) {
        base.receive(completion: completion)
    }

    override var customMirror: Mirror { return Mirror(reflecting: base) }

    override var description: String { return String(describing: base) }
}

internal final class ClosureBasedSubscriber<Input, Failure: Error>
    : SubscriberBoxBase<Input, Failure>
{

    private let _receiveSubscription: ((Subscription) -> Void)?
    private let _receiveValue: ((Input) -> Subscribers.Demand)?
    private let _receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?

    init(receiveSubscription: ((Subscription) -> Void)? = nil,
         receiveValue: ((Input) -> Subscribers.Demand)? = nil,
         receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil) {
        _receiveSubscription = receiveSubscription
        _receiveValue = receiveValue
        _receiveCompletion = receiveCompletion
    }

    override func receive(subscription: Subscription) {
        _receiveSubscription?(subscription)
    }

    override func receive(_ input: Input) -> Subscribers.Demand {
        return _receiveValue?(input) ?? .none
    }

    override func receive(completion: Subscribers.Completion<Failure>) {
        _receiveCompletion?(completion)
    }
}

internal final class SubjectSubscriber<S: Subject>
    : SubscriberBoxBase<S.Output, S.Failure>
{
    var parent: S?
    var upstreamSubscription: Subscription?

    init(_ parent: S) {
        self.parent = parent
    }

    override func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        subscription.request(.unlimited)
    }

    override func receive(_ input: S.Output) -> Subscribers.Demand {
        parent?.send(input)
        return .none
    }

    override func receive(completion: Subscribers.Completion<S.Failure>) {
        parent?.send(completion: completion)
    }

    override var description: String { return "Subject" }

    override var customMirror: Mirror {
        let children: [(label: String?, value: Any)] = [
            (label: "parent", value: parent as Any),
            (label: "upstreamSubscription", value: upstreamSubscription as Any)
        ]
        return Mirror(self, children: children)
    }
}

