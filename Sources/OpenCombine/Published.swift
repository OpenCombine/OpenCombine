//
//  Published.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 01/09/2019.
//

#if swift(>=5.1)
/// Adds a `Publisher` to a property.
///
/// Properties annotated with `@Published` contain both the stored value
/// and a publisher which sends any new values after the property value
/// has been sent. New subscribers will receive the current value
/// of the property first.
@propertyWrapper public struct Published<Value> {

    /// Initialize the storage of the Published
    /// property as well as the corresponding `Publisher`.
    public init(initialValue: Value) {
        value = initialValue
    }

    @available(*, unavailable)
    public init(wrappedValue: Value) {
        value = wrappedValue
    }

    public struct Publisher: OpenCombine.Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Value

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Never

        /// This function is called to attach the specified
        /// `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Value, Downstream.Failure == Never
        {
            subject.subscribe(subscriber)
        }

        fileprivate let subject: OpenCombine.CurrentValueSubject<Value, Never>

        fileprivate init(_ output: Output) {
            subject = .init(output)
        }
    }

    private var value: Value

    /// The property that can be accessed with the
    /// `$` syntax and allows access to the `Publisher`
    public var projectedValue: Publisher {
        mutating get {
            if let publisher = publisher {
                return publisher
            }
            let publisher = Publisher(value)
            self.publisher = publisher
            return publisher
        }
    }

    @available(*, unavailable, message:
        "@Published is only available on properties of classes")

    public var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            publisher?.subject.value = newValue
        }
    }

    private var publisher: Publisher?

    @available(*, unavailable, message:
        "This subscript is unavailable in OpenCombine yet")
    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Published<Value>>
    ) -> Value {
        get { fatalError() }
        set { fatalError() }
    }
}
#endif
