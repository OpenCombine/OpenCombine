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
public struct AnyPublisher<Output, Failure: Error>
  : CustomStringConvertible,
    CustomPlaygroundDisplayConvertible
{

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

    public var description: String {
        return "AnyPublisher"
    }

    public var playgroundDescription: Any {
        return description
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
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
    {
        box.subscribe(subscriber)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying
/// publisher.
@usableFromInline
internal class PublisherBoxBase<Output, Failure: Error>: Publisher {

    @inlinable
    internal init() {}

    @usableFromInline
    internal func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Failure == Downstream.Failure, Output == Downstream.Input
    {
        abstractMethod()
    }
}

@usableFromInline
internal final class PublisherBox<PublisherType: Publisher>
    : PublisherBoxBase<PublisherType.Output, PublisherType.Failure>
{
    @usableFromInline
    internal let base: PublisherType

    @inlinable
    internal init(base: PublisherType) {
        self.base = base
        super.init()
    }

    @inlinable
    override internal func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Failure == Downstream.Failure, Output == Downstream.Input
    {
        base.subscribe(subscriber)
    }
}
