//
//  Publisher.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// Declares that a type can transmit a sequence of values over time.
///
/// A publisher delivers elements to one or more `Subscriber` instances.
/// The subscriber’s `Input` and `Failure` associated types must match the `Output` and
/// `Failure` types declared by the publisher.
/// The publisher implements the `receive(subscriber:)`method to accept a subscriber.
///
/// After this, the publisher can call the following methods on the subscriber:
/// - `receive(subscription:)`: Acknowledges the subscribe request and returns
///   a `Subscription` instance. The subscriber uses the subscription to demand elements
///   from the publisher and can use it to cancel publishing.
/// - `receive(_:)`: Delivers one element from the publisher to the subscriber.
/// - `receive(completion:)`: Informs the subscriber that publishing has ended,
///   either normally or with an error.
///
/// Every `Publisher` must adhere to this contract for downstream subscribers to function
/// correctly.
///
/// Extensions on `Publisher` define a wide variety of _operators_ that you compose to
/// create sophisticated event-processing chains.
/// Each operator returns a type that implements the `Publisher` protocol
/// Most of these types exist as extensions on the `Publishers` enumeration.
/// For example, the `map(_:)` operator returns an instance of `Publishers.Map`.
///
/// # Creating Your Own Publishers
///
/// Rather than implementing the `Publisher` protocol yourself, you can create your own
/// publisher by using one of several types provided by the OpenCombine framework:
///
/// - Use a concrete subclass of `Subject`, such as `PassthroughSubject`, to publish
///   values on-demand by calling its `send(_:)` method.
/// - Use a `CurrentValueSubject` to publish whenever you update the subject’s underlying
///   value.
/// - Add the `@Published` annotation to a property of one of your own types. In doing so,
///   the property gains a publisher that emits an event whenever the property’s value
///   changes. See the `Published` type for an example of this approach.
public protocol Publisher {

    /// The kind of values published by this publisher.
    associatedtype Output

    /// The kind of errors this publisher might publish.
    ///
    /// Use `Never` if this `Publisher` does not publish errors.
    associatedtype Failure: Error

    /// Attaches the specified subscriber to this publisher.
    ///
    /// Always call this function instead of `receive(subscriber:)`.
    /// Adopters of `Publisher` must implement `receive(subscriber:)`. The implementation
    /// of `subscribe(_:)` provided by `Publisher` calls through to
    /// `receive(subscriber:)`.
    ///
    /// - Parameter subscriber: The subscriber to attach to this publisher. After
    ///   attaching, the subscriber can start to receive values.
    func receive<Subscriber: OpenCombine.Subscriber>(subscriber: Subscriber)
        where Failure == Subscriber.Failure, Output == Subscriber.Input
}

extension Publisher {

    /// Attaches the specified subscriber to this publisher.
    ///
    /// Always call this function instead of `receive(subscriber:)`.
    /// Adopters of `Publisher` must implement `receive(subscriber:)`.
    /// The implementation of `subscribe(_:)` in this extension calls through to
    /// `receive(subscriber:)`.
    /// - SeeAlso: `receive(subscriber:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`. After attaching,
    ///       the subscriber can start to receive values.
    public func subscribe<Subscriber: OpenCombine.Subscriber>(_ subscriber: Subscriber)
        where Failure == Subscriber.Failure, Output == Subscriber.Input
    {
        if let hook = DebugHook.getGlobalHook() {
            if var marker = subscriber as? SubscriberTapMarker {
                let anySubscriber = marker.inner
                    as! AnySubscriber<Subscriber.Input, Subscriber.Failure>
                hook.willReceive(publisher: self, subscriber: anySubscriber)
                receive(subscriber: subscriber)
                hook.didReceive(publisher: self, subscriber: anySubscriber)
            } else {
                let tap = SubscriberTap(subscriber: subscriber)
                hook.willReceive(publisher: self, subscriber: subscriber)
                receive(subscriber: tap)
                hook.didReceive(publisher: self, subscriber: subscriber)
            }
        } else {
            receive(subscriber: subscriber)
        }
    }

    /// Attaches the specified subject to this publisher.
    ///
    /// - Parameter subject: The subject to attach to this publisher.
    public func subscribe<Subject: OpenCombine.Subject>(
        _ subject: Subject
    ) -> AnyCancellable
        where Failure == Subject.Failure, Output == Subject.Output
    {
        let subscriber = SubjectSubscriber(subject)
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
