//
//  AnySubscriber.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A type-erasing subscriber.
///
/// Use an `AnySubscriber` to wrap an existing subscriber whose details you don’t want to
/// expose. You can also use `AnySubscriber` to create a custom subscriber by providing
/// closures for the methods defined in `Subscriber`, rather than implementing
/// `Subscriber` directly.
@frozen
public struct AnySubscriber<Input, Failure: Error>: Subscriber,
                                                    CustomStringConvertible,
                                                    CustomReflectable,
                                                    CustomPlaygroundDisplayConvertible
{
    @usableFromInline
    internal let box: AnySubscriberBase<Input, Failure>

    @usableFromInline
    internal let descriptionThunk: () -> String

    @usableFromInline
    internal let customMirrorThunk: () -> Mirror

    @usableFromInline
    internal let playgroundDescriptionThunk: () -> Any

    public let combineIdentifier: CombineIdentifier

    public var description: String { return descriptionThunk() }

    public var customMirror: Mirror { return customMirrorThunk() }

    /// A custom playground description for this instance.
    public var playgroundDescription: Any { return playgroundDescriptionThunk() }

    /// Creates a type-erasing subscriber to wrap an existing subscriber.
    ///
    /// - Parameter s: The subscriber to type-erase.
    @inline(__always)
    @inlinable
    public init<S>(_ s: S) where Input == S.Input, Failure == S.Failure, S: Subscriber {
        if let erased = s as? AnySubscriber<Input, Failure> {
            self = erased
        } else {
            combineIdentifier = s.combineIdentifier

            box = AnySubscriberBox(s)

            // The following use normal memory management semantics
            if let desc = s as? CustomStringConvertible {
                descriptionThunk = {
                    desc.description
                }
            } else {
                let fixedDescription = "\(type(of: s))"
                descriptionThunk = { fixedDescription }
            }

            customMirrorThunk = {
                if let mir = s as? CustomReflectable {
                    return mir.customMirror
                } else {
                    return Mirror(s, children: [:])
                }
            }

            if let play = s as? CustomPlaygroundDisplayConvertible {
                playgroundDescriptionThunk = { play.playgroundDescription }
            } else if let desc = s as? CustomStringConvertible {
                playgroundDescriptionThunk = { desc.description }
            } else {
                let fixedDescription = "\(type(of: s))"
                playgroundDescriptionThunk = { fixedDescription }
            }
        }
    }

    public init<Subject: OpenCombine.Subject>(_ subject: Subject)
        where Input == Subject.Output, Failure == Subject.Failure
    {
        self.init(SubjectSubscriber(subject))
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
    @inline(__always)
    @inlinable
    public init(receiveSubscription: ((Subscription) -> Void)? = nil,
                receiveValue: ((Input) -> Subscribers.Demand)? = nil,
                receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil) {

        box = ClosureBasedAnySubscriber(
            receiveSubscription ?? { _ in },
            receiveValue ?? { _ in .none },
            receiveCompletion ?? { _ in }
        )

        combineIdentifier = CombineIdentifier()
        descriptionThunk = { "Anonymous AnySubscriber" }
        customMirrorThunk = { Mirror(reflecting: "Anonymous AnySubscriber") }
        playgroundDescriptionThunk = { "Anonymous AnySubscriber" }
    }

    @inline(__always)
    @inlinable
    public func receive(subscription: Subscription) {
        box.receive(subscription: subscription)
    }

    @inline(__always)
    @inlinable
    public func receive(_ value: Input) -> Subscribers.Demand {
        box.receive(value)
    }

    @inline(__always)
    @inlinable
    public func receive(completion: Subscribers.Completion<Failure>) {
        box.receive(completion: completion)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying
/// subscriber.
@usableFromInline
@_fixed_layout
internal class AnySubscriberBase<Input, Failure: Error>: Subscriber {

    @inline(__always)
    @inlinable
    internal init() {}

    @inline(__always)
    @inlinable
    deinit {}

    @usableFromInline
    internal func receive(subscription: Subscription) {
        abstractMethod()
    }

    @usableFromInline
    internal func receive(_ input: Input) -> Subscribers.Demand {
        abstractMethod()
    }

    @usableFromInline
    internal func receive(completion: Subscribers.Completion<Failure>) {
        abstractMethod()
    }
}

@usableFromInline
@_fixed_layout
internal final class AnySubscriberBox<Base: Subscriber>
    : AnySubscriberBase<Base.Input, Base.Failure>
{
    @usableFromInline
    internal let base: Base

    @inlinable
    internal init(_ base: Base) {
        self.base = base
    }

    @inlinable
    deinit {}

    @inlinable
    override internal func receive(subscription: Subscription) {
        base.receive(subscription: subscription)
    }

    @inlinable
    override internal func receive(_ input: Base.Input) -> Subscribers.Demand {
        return base.receive(input)
    }

    @inlinable
    override internal func receive(completion: Subscribers.Completion<Base.Failure>) {
        base.receive(completion: completion)
    }
}

@usableFromInline
@_fixed_layout
internal final class ClosureBasedAnySubscriber<Input, Failure: Error>
    : AnySubscriberBase<Input, Failure>
{
    @usableFromInline
    final internal let receiveSubscriptionThunk: (Subscription) -> Void

    @usableFromInline
    final internal let receiveValueThunk: (Input) -> Subscribers.Demand

    @usableFromInline
    final internal let receiveCompletionThunk: (Subscribers.Completion<Failure>) -> Void

    @inlinable
    internal init(_ rcvSubscription: @escaping (Subscription) -> Void,
                  _ rcvValue: @escaping (Input) -> Subscribers.Demand,
                  _ rcvCompletion: @escaping (Subscribers.Completion<Failure>) -> Void) {
        receiveSubscriptionThunk = rcvSubscription
        receiveValueThunk = rcvValue
        receiveCompletionThunk = rcvCompletion
    }

    @inlinable
    deinit {}

    @inlinable
    override internal func receive(subscription: Subscription) {
        receiveSubscriptionThunk(subscription)
    }

    @inlinable
    override internal func receive(_ input: Input) -> Subscribers.Demand {
        return receiveValueThunk(input)
    }

    @inlinable
    override internal func receive(completion: Subscribers.Completion<Failure>) {
        receiveCompletionThunk(completion)
    }
}
