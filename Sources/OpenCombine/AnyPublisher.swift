//
//  AnyPublisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A type-erasing publisher.
///
/// Use `AnyPublisher` to wrap a publisher whose type has details you don’t want to expose
/// to subscribers or other publishers.
public struct AnyPublisher<Output, Failure: Error> {

    @usableFromInline
    internal let box: PublisherBoxBase<Output, Failure>

    /// Creates a type-erasing publisher to wrap the provided publisher.
    ///
    /// - Parameters:
    ///   - publisher: A publisher to wrap with a type-eraser.
    @inlinable
    public init<PublisherType: Publisher>(_ publisher: PublisherType)
        where Output == PublisherType.Output, Failure == PublisherType.Failure
    {
        box = PublisherBox(base: publisher)
    }

    /// Creates a type-erasing publisher implemented by the provided closure.
    ///
    /// - Parameters:
    ///   - subscribe: A closure to invoke when a subscriber subscribes to the publisher.
    @inlinable
    public init(_ subscribe: @escaping (AnySubscriber<Output, Failure>) -> Void) {
        box = PublisherBox(base: ClosureBasedPublisher(subscribe))
    }
}

extension AnyPublisher: Publisher {

    /// This function is called to attach the specified `Subscriber` to this `Publisher`
    /// by `subscribe(_:)`
    ///
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`.
    ///                   once attached it can begin to receive values.
    @inlinable
    public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Output == SubscriberType.Input, Failure == SubscriberType.Failure
    {
        box.receive(subscriber: subscriber)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying
/// publisher.
@usableFromInline
internal class PublisherBoxBase<Output, Failure: Error>: Publisher {

    @inlinable
    internal init() {}

    @inlinable
    internal func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        fatalError()
    }
}

@usableFromInline
internal final class PublisherBox<PublisherType: Publisher>
    : PublisherBoxBase<PublisherType.Output,
      PublisherType.Failure> {

    @usableFromInline
    internal let base: PublisherType

    @inlinable
    internal init(base: PublisherType) {
        self.base = base
        super.init()
    }

    @inlinable
    override internal func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        base.receive(subscriber: subscriber)
    }
}

@usableFromInline
internal struct ClosureBasedPublisher<Output, Failure: Error>: Publisher {

    @usableFromInline
    internal let subscribe: (AnySubscriber<Output, Failure>) -> Void

    @inlinable
    internal init(_ subscribe: @escaping (AnySubscriber<Output, Failure>) -> Void) {
        self.subscribe = subscribe
    }

    @inlinable
    internal func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        if let anySubscriber = subscriber as? AnySubscriber<Output, Failure> {
            subscribe(anySubscriber)
        } else {
            subscribe(AnySubscriber(subscriber))
        }
    }
}
