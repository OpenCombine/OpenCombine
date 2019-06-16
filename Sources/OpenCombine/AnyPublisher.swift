//
//  AnyPublisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A type-erasing publisher.
///
/// Use `AnyPublisher` to wrap a publisher whose type has details you don’t want to expose to subscribers or other
/// publishers.
public struct AnyPublisher<Output, Failure: Error> {

    @usableFromInline
    internal let box: PublisherBoxBase<Output, Failure>

    /// Creates a type-erasing publisher to wrap the provided publisher.
    ///
    /// - Parameters:
    ///   - publisher: A publisher to wrap with a type-eraser.
    @inlinable
    public init<P: Publisher>(_ publisher: P)
        where Output == P.Output, Failure == P.Failure
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

    /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
    ///
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`.
    ///                   once attached it can begin to receive values.
    @inlinable
    public func receive<S: Subscriber>(subscriber: S)
        where Output == S.Input, Failure == S.Failure
    {
        box.receive(subscriber: subscriber)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying publisher.
@usableFromInline
internal class PublisherBoxBase<Output, Failure: Error>: Publisher {

    @inlinable
    init() {}

    @inlinable
    func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        fatalError()
    }
}

@usableFromInline
internal final class PublisherBox<P: Publisher>: PublisherBoxBase<P.Output, P.Failure> {

    @usableFromInline
    let base: P

    @inlinable
    init(base: P) {
        self.base = base
        super.init()
    }

    @inlinable
    override func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        base.receive(subscriber: subscriber)
    }
}

@usableFromInline
internal struct ClosureBasedPublisher<Output, Failure: Error>: Publisher {

    @usableFromInline
    let subscribe: (AnySubscriber<Output, Failure>) -> Void

    @inlinable
    init(_ subscribe: @escaping (AnySubscriber<Output, Failure>) -> Void) {
        self.subscribe = subscribe
    }

    @inlinable
    func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        subscribe(AnySubscriber(subscriber))
    }
}
