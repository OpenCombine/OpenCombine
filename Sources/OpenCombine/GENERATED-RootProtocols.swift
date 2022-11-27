// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃                                                                                     ┃
// ┃                   Auto-generated from GYB template. DO NOT EDIT!                    ┃
// ┃                                                                                     ┃
// ┃                                                                                     ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//
//  RootProtocols.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

#if compiler(>=5.7)
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
public protocol Publisher<Output, Failure> {

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

/// A publisher that exposes a method for outside callers to publish elements.
///
/// A subject is a publisher that you can use to ”inject” values into a stream, by calling
/// its `send()` method. This can be useful for adapting existing imperative code to the
/// Combine model.
public protocol Subject<Output, Failure>: AnyObject, Publisher {

    /// Sends a value to the subscriber.
    ///
    /// - Parameter value: The value to send.
    func send(_ value: Output)

    /// Sends a completion signal to the subscriber.
    ///
    /// - Parameter completion: A `Completion` instance which indicates whether publishing
    ///   has finished normally or failed with an error.
    func send(completion: Subscribers.Completion<Failure>)

    /// Sends a subscription to the subscriber.
    ///
    /// This call provides the `Subject` an opportunity to establish demand for any new
    /// upstream subscriptions.
    ///
    /// - Parameter subscription: The subscription instance through which the subscriber
    ///   can request elements.
    func send(subscription: Subscription)
}

/// A publisher that provides an explicit means of connecting and canceling publication.
///
/// Use a `ConnectablePublisher` when you need to perform additional configuration or
/// setup prior to producing any elements.
///
/// This publisher doesn’t produce any elements until you call its `connect()` method.
///
/// Use `makeConnectable()` to create a `ConnectablePublisher` from any publisher whose
/// failure type is `Never`.
public protocol ConnectablePublisher<Output, Failure>: Publisher {

    /// Connects to the publisher, allowing it to produce elements, and returns
    /// an instance with which to cancel publishing.
    ///
    /// - Returns: A `Cancellable` instance that you use to cancel publishing.
    func connect() -> Cancellable
}

/// A protocol that declares a type that can receive input from a publisher.
///
/// A `Subscriber` instance receives a stream of elements from a `Publisher`, along with
/// life cycle events describing changes to their relationship. A given subscriber’s
/// `Input` and `Failure` associated types must match the `Output` and `Failure` of its
/// corresponding publisher.
///
/// You connect a subscriber to a publisher by calling the publisher’s `subscribe(_:)`
/// method.  After making this call, the publisher invokes the subscriber’s
/// `receive(subscription:)` method. This gives the subscriber a `Subscription` instance,
/// which it uses to demand elements from the publisher, and to optionally cancel
/// the subscription. After the subscriber makes an initial demand, the publisher calls
/// `receive(_:)`, possibly asynchronously, to deliver newly-published elements.
/// If the publisher stops publishing, it calls `receive(completion:)`, using a parameter
/// of type `Subscribers.Completion` to indicate whether publishing completes normally or
/// with an error.
///
/// OpenCombine provides the following subscribers as operators on the `Publisher` type:
///
/// - `sink(receiveCompletion:receiveValue:)` executes arbitrary closures when
///   it receives a completion signal and each time it receives a new element.
/// - `assign(to:on:)` writes each newly-received value to a property identified by
///   a key path on a given instance.
public protocol Subscriber<Input, Failure>: CustomCombineIdentifierConvertible {

    /// The kind of values this subscriber receives.
    associatedtype Input

    /// The kind of errors this subscriber might receive.
    ///
    /// Use `Never` if this `Subscriber` cannot receive errors.
    associatedtype Failure: Error

    /// Tells the subscriber that it has successfully subscribed to the publisher and may
    /// request items.
    ///
    /// Use the received `Subscription` to request items from the publisher.
    /// - Parameter subscription: A subscription that represents the connection between
    ///   publisher and subscriber.
    func receive(subscription: Subscription)

    /// Tells the subscriber that the publisher has produced an element.
    ///
    /// - Parameter input: The published element.
    /// - Returns: A `Subscribers.Demand` instance indicating how many more elements
    ///   the subscriber expects to receive.
    func receive(_ input: Input) -> Subscribers.Demand

    /// Tells the subscriber that the publisher has completed publishing, either normally
    /// or with an error.
    ///
    /// - Parameter completion: A `Subscribers.Completion` case indicating whether
    ///   publishing completed normally or with an error.
    func receive(completion: Subscribers.Completion<Failure>)
}

/// A protocol that defines when and how to execute a closure.
///
/// You can use a scheduler to execute code as soon as possible, or after a future date.
/// Individual scheduler implementations use whatever time-keeping system makes sense
/// for them. Schedulers express this as their `SchedulerTimeType`. Since this type
/// conforms to `SchedulerTimeIntervalConvertible`, you can always express these times
/// with the convenience functions like `.milliseconds(500)`. Schedulers can accept
/// options to control how they execute the actions passed to them. These options may
/// control factors like which threads or dispatch queues execute the actions.
public protocol Scheduler<SchedulerTimeType> {

    /// Describes an instant in time for this scheduler.
    associatedtype SchedulerTimeType: Strideable
        where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible

    /// A type that defines options accepted by the scheduler.
    ///
    /// This type is freely definable by each `Scheduler`. Typically, operations that
    /// take a `Scheduler` parameter will also take `SchedulerOptions`.
    associatedtype SchedulerOptions

    /// This scheduler’s definition of the current moment in time.
    var now: SchedulerTimeType { get }

    /// The minimum tolerance allowed by the scheduler.
    var minimumTolerance: SchedulerTimeType.Stride { get }

    /// Performs the action at the next possible opportunity.
    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void)

    /// Performs the action at some time after the specified date.
    func schedule(after date: SchedulerTimeType,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void)

    /// Performs the action at some time after the specified date, at the specified
    /// frequency, optionally taking into account tolerance if possible.
    func schedule(after date: SchedulerTimeType,
                  interval: SchedulerTimeType.Stride,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) -> Cancellable
}
#else
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

/// A publisher that exposes a method for outside callers to publish elements.
///
/// A subject is a publisher that you can use to ”inject” values into a stream, by calling
/// its `send()` method. This can be useful for adapting existing imperative code to the
/// Combine model.
public protocol Subject: AnyObject, Publisher {

    /// Sends a value to the subscriber.
    ///
    /// - Parameter value: The value to send.
    func send(_ value: Output)

    /// Sends a completion signal to the subscriber.
    ///
    /// - Parameter completion: A `Completion` instance which indicates whether publishing
    ///   has finished normally or failed with an error.
    func send(completion: Subscribers.Completion<Failure>)

    /// Sends a subscription to the subscriber.
    ///
    /// This call provides the `Subject` an opportunity to establish demand for any new
    /// upstream subscriptions.
    ///
    /// - Parameter subscription: The subscription instance through which the subscriber
    ///   can request elements.
    func send(subscription: Subscription)
}

/// A publisher that provides an explicit means of connecting and canceling publication.
///
/// Use a `ConnectablePublisher` when you need to perform additional configuration or
/// setup prior to producing any elements.
///
/// This publisher doesn’t produce any elements until you call its `connect()` method.
///
/// Use `makeConnectable()` to create a `ConnectablePublisher` from any publisher whose
/// failure type is `Never`.
public protocol ConnectablePublisher: Publisher {

    /// Connects to the publisher, allowing it to produce elements, and returns
    /// an instance with which to cancel publishing.
    ///
    /// - Returns: A `Cancellable` instance that you use to cancel publishing.
    func connect() -> Cancellable
}

/// A protocol that declares a type that can receive input from a publisher.
///
/// A `Subscriber` instance receives a stream of elements from a `Publisher`, along with
/// life cycle events describing changes to their relationship. A given subscriber’s
/// `Input` and `Failure` associated types must match the `Output` and `Failure` of its
/// corresponding publisher.
///
/// You connect a subscriber to a publisher by calling the publisher’s `subscribe(_:)`
/// method.  After making this call, the publisher invokes the subscriber’s
/// `receive(subscription:)` method. This gives the subscriber a `Subscription` instance,
/// which it uses to demand elements from the publisher, and to optionally cancel
/// the subscription. After the subscriber makes an initial demand, the publisher calls
/// `receive(_:)`, possibly asynchronously, to deliver newly-published elements.
/// If the publisher stops publishing, it calls `receive(completion:)`, using a parameter
/// of type `Subscribers.Completion` to indicate whether publishing completes normally or
/// with an error.
///
/// OpenCombine provides the following subscribers as operators on the `Publisher` type:
///
/// - `sink(receiveCompletion:receiveValue:)` executes arbitrary closures when
///   it receives a completion signal and each time it receives a new element.
/// - `assign(to:on:)` writes each newly-received value to a property identified by
///   a key path on a given instance.
public protocol Subscriber: CustomCombineIdentifierConvertible {

    /// The kind of values this subscriber receives.
    associatedtype Input

    /// The kind of errors this subscriber might receive.
    ///
    /// Use `Never` if this `Subscriber` cannot receive errors.
    associatedtype Failure: Error

    /// Tells the subscriber that it has successfully subscribed to the publisher and may
    /// request items.
    ///
    /// Use the received `Subscription` to request items from the publisher.
    /// - Parameter subscription: A subscription that represents the connection between
    ///   publisher and subscriber.
    func receive(subscription: Subscription)

    /// Tells the subscriber that the publisher has produced an element.
    ///
    /// - Parameter input: The published element.
    /// - Returns: A `Subscribers.Demand` instance indicating how many more elements
    ///   the subscriber expects to receive.
    func receive(_ input: Input) -> Subscribers.Demand

    /// Tells the subscriber that the publisher has completed publishing, either normally
    /// or with an error.
    ///
    /// - Parameter completion: A `Subscribers.Completion` case indicating whether
    ///   publishing completed normally or with an error.
    func receive(completion: Subscribers.Completion<Failure>)
}

/// A protocol that defines when and how to execute a closure.
///
/// You can use a scheduler to execute code as soon as possible, or after a future date.
/// Individual scheduler implementations use whatever time-keeping system makes sense
/// for them. Schedulers express this as their `SchedulerTimeType`. Since this type
/// conforms to `SchedulerTimeIntervalConvertible`, you can always express these times
/// with the convenience functions like `.milliseconds(500)`. Schedulers can accept
/// options to control how they execute the actions passed to them. These options may
/// control factors like which threads or dispatch queues execute the actions.
public protocol Scheduler {

    /// Describes an instant in time for this scheduler.
    associatedtype SchedulerTimeType: Strideable
        where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible

    /// A type that defines options accepted by the scheduler.
    ///
    /// This type is freely definable by each `Scheduler`. Typically, operations that
    /// take a `Scheduler` parameter will also take `SchedulerOptions`.
    associatedtype SchedulerOptions

    /// This scheduler’s definition of the current moment in time.
    var now: SchedulerTimeType { get }

    /// The minimum tolerance allowed by the scheduler.
    var minimumTolerance: SchedulerTimeType.Stride { get }

    /// Performs the action at the next possible opportunity.
    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void)

    /// Performs the action at some time after the specified date.
    func schedule(after date: SchedulerTimeType,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void)

    /// Performs the action at some time after the specified date, at the specified
    /// frequency, optionally taking into account tolerance if possible.
    func schedule(after date: SchedulerTimeType,
                  interval: SchedulerTimeType.Stride,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) -> Cancellable
}
#endif
