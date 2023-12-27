//
//  AnyPublisher.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//  Audited for Combine 2023

extension Publisher {
    /// Wraps this publisher with a type eraser.
    ///
    /// Use ``Publisher/eraseToAnyPublisher()`` to expose an instance of ``AnyPublisher`` to the downstream subscriber, rather than this publisher’s actual type.
    /// This form of _type erasure_ preserves abstraction across API boundaries, such as different modules.
    /// When you expose your publishers as the ``AnyPublisher`` type, you can change the underlying implementation over time without affecting existing clients.
    ///
    /// The following example shows two types that each have a `publisher` property. `TypeWithSubject` exposes this property as its actual type, ``PassthroughSubject``, while `TypeWithErasedSubject` uses ``Publisher/eraseToAnyPublisher()`` to expose it as an ``AnyPublisher``. As seen in the output, a caller from another module can access `TypeWithSubject.publisher` as its native type. This means you can’t change your publisher to a different type without breaking the caller. By comparison, `TypeWithErasedSubject.publisher` appears to callers as an ``AnyPublisher``, so you can change the underlying publisher type at will.
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
        AnyPublisher(self)
    }
}

/// A publisher that performs type erasure by wrapping another publisher.
///
/// ``AnyPublisher`` is a concrete implementation of ``Publisher`` that has no significant properties of its own, and passes through elements and completion values from its upstream publisher.
///
/// Use ``AnyPublisher`` to wrap a publisher whose type has details you don’t want to expose across API boundaries, such as different modules. Wrapping a ``Subject`` with ``AnyPublisher`` also prevents callers from accessing its ``Subject/send(_:)`` method. When you use type erasure this way, you can change the underlying publisher implementation over time without affecting existing clients.
///
/// You can use OpenCombine’s ``Publisher/eraseToAnyPublisher()`` operator to wrap a publisher with ``AnyPublisher``.
@frozen
public struct AnyPublisher<Output, Failure: Error>: CustomStringConvertible, CustomPlaygroundDisplayConvertible
{
    @usableFromInline
    let box: PublisherBoxBase<Output, Failure>

    public var description: String { "AnyPublisher" }

    public var playgroundDescription: Any { description }
    
    /// Creates a type-erasing publisher to wrap the provided publisher.
    ///
    /// - Parameter publisher: A publisher to wrap with a type-eraser.
    @inlinable
    public init<P>(_ publisher: P) where Output == P.Output, Failure == P.Failure, P: Publisher {
        // If this has already been boxed, avoid boxing again
        if let erased = publisher as? AnyPublisher<Output, Failure> {
            box = erased.box
        } else {
            box = PublisherBox(publisher)
        }
    }
}

extension AnyPublisher: Publisher {
    @inlinable
    public func receive<S>(subscriber: S) where Output == S.Input, Failure == S.Failure, S: Subscriber {
        box.receive(subscriber: subscriber)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying
/// publisher.
@usableFromInline
@_fixed_layout
class PublisherBoxBase<Output, Failure: Error>: Publisher {
    @inlinable
    init() {}
    
    @inlinable deinit {}

    @usableFromInline
    func receive<S>(subscriber _: S) where Output == S.Input, Failure == S.Failure, S: Subscriber {
        abstractMethod()
    }
}

@usableFromInline
@_fixed_layout
final class PublisherBox<Base: Publisher>: PublisherBoxBase<Base.Output, Base.Failure> {
    @usableFromInline
    let base: Base

    @inlinable
    init(_ base: Base) {
        self.base = base
    }
    
    @inlinable deinit {}

    @inlinable
    override final func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input
    {
        base.receive(subscriber: subscriber)
    }
}
