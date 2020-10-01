//
//  AnyPublisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

extension Publisher {

    /// Wraps this publisher with a type eraser.
    ///
    /// Use `eraseToAnyPublisher()` to expose an instance of `AnyPublishe`` to
    /// the downstream subscriber, rather than this publisher’s actual type.
    /// This form of _type erasure_ preserves abstraction across API boundaries, such as
    /// different modules.
    /// When you expose your publishers as the `AnyPublisher` type, you can change
    /// the underlying implementation over time without affecting existing clients.
    ///
    /// The following example shows two types that each have a `publisher` property.
    /// `TypeWithSubject` exposes this property as its actual type, `PassthroughSubject`,
    /// while `TypeWithErasedSubject` uses `eraseToAnyPublisher()` to expose it as
    /// an `AnyPublisher`. As seen in the output, a caller from another module can access
    /// `TypeWithSubject.publisher` as its native type. This means you can’t change your
    /// publisher to a different type without breaking the caller. By comparison,
    /// `TypeWithErasedSubject.publisher` appears to callers as an `AnyPublisher`, so you
    /// can change the underlying publisher type at will.
    ///
    ///     public class TypeWithSubject {
    ///         public let publisher: some Publisher = PassthroughSubject<Int,Never>()
    ///     }
    ///     public class TypeWithErasedSubject {
    ///         public let publisher: some Publisher = PassthroughSubject<Int,Never>()
    ///             .eraseToAnyPublisher()
    ///     }
    ///
    ///     // In another module:
    ///     let nonErased = TypeWithSubject()
    ///     if let subject = nonErased.publisher as? PassthroughSubject<Int,Never> {
    ///         print("Successfully cast nonErased.publisher.")
    ///     }
    ///     let erased = TypeWithErasedSubject()
    ///     if let subject = erased.publisher as? PassthroughSubject<Int,Never> {
    ///         print("Successfully cast erased.publisher.")
    ///     }
    ///
    ///     // Prints "Successfully cast nonErased.publisher."
    ///
    /// - Returns: An ``AnyPublisher`` wrapping this publisher.
    @inlinable
    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        return .init(self)
    }
}

/// A type-erasing publisher.
///
/// Use `AnyPublisher` to wrap a publisher whose type has details you don’t want to expose
/// across API boundaries, such as different modules. Wrapping a `Subject` with
/// `AnyPublisher` also prevents callers from accessing its `send(_:)` method. When you
/// use type erasure this way, you can change the underlying publisher implementation over
/// time without affecting existing clients.
///
/// You can use OpenCombine’s `eraseToAnyPublisher()` operator to wrap a publisher with
/// `AnyPublisher`.
public struct AnyPublisher<Output, Failure: Error>
  : CustomStringConvertible,
    CustomPlaygroundDisplayConvertible
{
    @usableFromInline
    internal let box: PublisherBoxBase<Output, Failure>

    /// Creates a type-erasing publisher to wrap the provided publisher.
    ///
    /// - Parameter publisher: A publisher to wrap with a type-eraser.
    @inlinable
    public init<PublisherType: Publisher>(_ publisher: PublisherType)
        where Output == PublisherType.Output, Failure == PublisherType.Failure
    {
        // If this has already been boxed, avoid boxing again
        if let erased = publisher as? AnyPublisher<Output, Failure> {
            box = erased.box
        } else {
            box = PublisherBox(base: publisher)
        }
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
        box.receive(subscriber: subscriber)
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
        base.receive(subscriber: subscriber)
    }
}
