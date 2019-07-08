//
//  AnySubscriber.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A type-erasing subscriber.
///
/// Use an `AnySubscriber` to wrap an existing subscriber whose details you don’t want
/// to expose. You can also use `AnySubscriber` to create a custom subscriber by providing
/// closures for `Subscriber`’s methods, rather than implementing `Subscriber` directly.
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
    public init<SubscriberType: Subscriber>(_ subscriber: SubscriberType)
        where Input == SubscriberType.Input, Failure == SubscriberType.Failure
    {
        _box = SubscriberBox(base: subscriber)
        combineIdentifier = subscriber.combineIdentifier
    }

    public init<SubjectType: Subject>(_ subject: SubjectType)
        where Input == SubjectType.Output, Failure == SubjectType.Failure
    {
        _box = SubjectSubscriber(subject)
        combineIdentifier = CombineIdentifier(_box)
    }

    /// Creates a type-erasing subscriber that executes the provided closures.
    ///
    /// - Parameters:
    ///   - receiveSubscription: A closure to execute when the subscriber receives
    ///     the initial subscription from the publisher.
    ///   - receiveValue: A closure to execute when the subscriber receives a value from
    ///     the publisher.
    ///   - receiveCompletion: A closure to execute when the subscriber receives
    ///     a completion callback from the publisher.
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

/// A type-erasing base class. Its concrete subclass is generic over the underlying
/// publisher.
internal class SubscriberBoxBase<Input, Failure: Error>: Subscriber,
                                                         CustomStringConvertible,
                                                         CustomReflectable {

    internal func receive(subscription: Subscription) {
        fatalError()
    }

    internal func receive(_ input: Input) -> Subscribers.Demand {
        fatalError()
    }

    internal func receive(completion: Subscribers.Completion<Failure>) {
        fatalError()
    }

    internal var description: String { return "AnySubscriber" }

    internal var customMirror: Mirror {
        return Mirror(combineIdentifier, children: EmptyCollection())
    }
}

internal final class SubscriberBox<SubscriberType: Subscriber>
    : SubscriberBoxBase<SubscriberType.Input, SubscriberType.Failure>
{

    private let base: SubscriberType

    internal init(base: SubscriberType) {
        self.base = base
    }

    override internal func receive(subscription: Subscription) {
        base.receive(subscription: subscription)
    }

    override internal func receive(_ input: Input) -> Subscribers.Demand {
        return base.receive(input)
    }

    override internal func receive(completion: Subscribers.Completion<Failure>) {
        base.receive(completion: completion)
    }

    override internal var customMirror: Mirror { return Mirror(reflecting: base) }

    override internal var description: String { return String(describing: base) }
}

internal final class ClosureBasedSubscriber<Input, Failure: Error>
    : SubscriberBoxBase<Input, Failure>
{

    private let _receiveSubscription: ((Subscription) -> Void)?
    private let _receiveValue: ((Input) -> Subscribers.Demand)?
    private let _receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?

    internal init(receiveSubscription: ((Subscription) -> Void)? = nil,
                  receiveValue: ((Input) -> Subscribers.Demand)? = nil,
                  receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil) {
        _receiveSubscription = receiveSubscription
        _receiveValue = receiveValue
        _receiveCompletion = receiveCompletion
    }

    override internal func receive(subscription: Subscription) {
        _receiveSubscription?(subscription)
    }

    override internal func receive(_ input: Input) -> Subscribers.Demand {
        return _receiveValue?(input) ?? .none
    }

    override internal func receive(completion: Subscribers.Completion<Failure>) {
        _receiveCompletion?(completion)
    }
}

internal final class SubjectSubscriber<SubjectType: Subject>
    : SubscriberBoxBase<SubjectType.Output, SubjectType.Failure>,
      Subscription
{
    internal var parent: SubjectType?
    internal var upstreamSubscription: Subscription?

    internal init(_ parent: SubjectType) {
        self.parent = parent
    }

    override internal func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        subscription.request(.unlimited)
    }

    override internal func receive(_ input: Input) -> Subscribers.Demand {
        parent?.send(input)
        return .none
    }

    override internal func receive(completion: Subscribers.Completion<Failure>) {
        parent?.send(completion: completion)
    }

    override internal var description: String { return "Subject" }

    override internal var customMirror: Mirror {
        let children: [(label: String?, value: Any)] = [
            (label: "parent", value: parent as Any),
            (label: "upstreamSubscription", value: upstreamSubscription as Any)
        ]
        return Mirror(self, children: children)
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
        parent = nil
    }
}
