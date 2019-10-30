//
//  ObservableObject.swift
//  
//
//  Created by Sergej Jaskiewicz on 08/09/2019.
//

// We use type metadata in the implementation of ObservableObject,
// but type metadata is stable only on Darwin. There are no such guarantees
// on non-Apple platforms (yet).
//
// This means that on Linux the layout of type metadata can change in a new Swift release,
// which will cause bugs that are hard to track (basically, undefined behavior).
//
// Whenever a new Swift version is available, we well test OpenCombine against it,
// and if everything works, release an update as soon as possible where the maximum
// supported Swift version is incremented.
#if !canImport(Darwin) && swift(>=5.1.50)
#warning("""
ObservableObject is not guaranteed to work on non-Apple platforms with this version \
of Swift because its implementation relies on ABI stability.

In order to fix this warning, please update to the newest version of OpenCombine, \
or create an issue at https://github.com/broadwaylamb/OpenCombine if there is no \
newer version yet.
""")
#endif

import COpenCombineHelpers

private protocol _ObservableObjectProperty {
    var objectWillChange: ObservableObjectPublisher? { get set }
}

extension _ObservableObjectProperty {

    fileprivate static func setPublisher(
        _ publisher: ObservableObjectPublisher,
        on publishedStorage: UnsafeMutableRawPointer
    ) {
        // It is safe to call assumingMemoryBound here because we know for sure
        // that the actual type of the pointee is Self.
        publishedStorage
            .assumingMemoryBound(to: Self.self)
            .pointee
            .objectWillChange = publisher
    }

    fileprivate static func getPublisher(
        from publishedStorage: UnsafeMutableRawPointer
    ) -> ObservableObjectPublisher? {
        // It is safe to call assumingMemoryBound here because we know for sure
        // that the actual type of the pointee is Self.
        return publishedStorage
            .assumingMemoryBound(to: Self.self)
            .pointee
            .objectWillChange
    }
}

extension Published: _ObservableObjectProperty {}

/// A type of object with a publisher that emits before the object has changed.
///
/// By default an `ObservableObject` will synthesize an `objectWillChange`
/// publisher that emits before any of its `@Published` properties changes:
///
///     class Contact : ObservableObject {
///         @Published var name: String
///         @Published var age: Int
///
///         init(name: String, age: Int) {
///             self.name = name
///             self.age = age
///         }
///
///         func haveBirthday() -> Int {
///             age += 1
///         }
///     }
///
///     let john = Contact(name: "John Appleseed", age: 24)
///     john.objectWillChange.sink { _ in print("will change") }
///     print(john.haveBirthday)
///     // Prints "will change"
///     // Prints "25"
///
public protocol ObservableObject: AnyObject {

    /// The type of publisher that emits before the object has changed.
    associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher
        where ObjectWillChangePublisher.Failure == Never

    /// A publisher that emits before the object has changed.
    var objectWillChange: ObjectWillChangePublisher { get }
}

private struct EnumeratorContext {
    var installedPublisher: ObservableObjectPublisher?
    let observableObjectInstance: UnsafeMutableRawPointer
}

extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {

    /// A publisher that emits before the object has changed.
    public var objectWillChange: ObservableObjectPublisher {

        var context = EnumeratorContext(
            installedPublisher: nil,
            observableObjectInstance: Unmanaged.passUnretained(self).toOpaque()
        )

        let enumerator: OpenCombineFieldEnumerator =
            { enumeratorContext, fieldName, fieldOffset, fieldTypeMetadataPtr in

                let _fieldType = unsafeBitCast(fieldTypeMetadataPtr, to: Any.Type.self)

                print(String(cString: fieldName))

                let context = enumeratorContext
                    .unsafelyUnwrapped
                    .assumingMemoryBound(to: EnumeratorContext.self)

                let storage = context
                    .pointee
                    .observableObjectInstance
                    .advanced(by: fieldOffset)

                guard let fieldType = _fieldType as? _ObservableObjectProperty.Type else {
                    // Visit other fields until we meet a @Published field
                    return true
                }

                // Now we know that the field is @Published.

                if let alreadyInstalledPublisher = fieldType.getPublisher(from: storage) {

                    context.pointee.installedPublisher = alreadyInstalledPublisher

                    // Don't visit other fields, as all @Published fields
                    // already have a publisher installed.
                    return false
                }

                // Okay, this field doesn't have a publisher installed.
                // This means that other fields don't have it either
                // (because we install it only once and fields can't be added at runtime).

                var lazilyCreatedPublisher: ObjectWillChangePublisher {
                    if let publisher = context.pointee.installedPublisher {
                        return publisher
                    }
                    let publisher = ObservableObjectPublisher()
                    context.pointee.installedPublisher = publisher
                    return publisher
                }

                fieldType.setPublisher(lazilyCreatedPublisher, on: storage)

                // Continue visiting other fields.
                return true
            }

        enumerateClassFields(
            typeMetadata: unsafeBitCast(Self.self, to: UnsafeRawPointer.self),
            enumeratorContext: &context,
            enumerator: enumerator
        )

        return context.installedPublisher ?? ObservableObjectPublisher()
    }
}

/// The default publisher of an `ObservableObject`.
public final class ObservableObjectPublisher: Publisher {

    public typealias Output = Void

    public typealias Failure = Never

    private let subject: PassthroughSubject<Void, Never>

    public init() {
        subject = .init()
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Void, Downstream.Failure == Never
    {
        subject.subscribe(subscriber)
    }

    public func send() {
        subject.send()
    }
}
