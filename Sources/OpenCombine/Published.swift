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
/// Note that the `@Published` property is class-constrained.
/// Use it with properties of classes, not with non-class types like structures.
@available(swift, introduced: 5.1)
@propertyWrapper
public struct Published<Value> {

    /// Initialize the storage of the `Published` property as well as the corresponding
    /// `Publisher`.
    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }

    /// Initialize the storage of the `Published` property as well as the corresponding
    /// `Publisher`.
    public init(wrappedValue: Value) {
        value = wrappedValue
    }

    /// A publisher for properties marked with the `@Published` attribute.
    public struct Publisher: OpenCombine.Publisher {

        public typealias Output = Value

        public typealias Failure = Never

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

    private var publisher: Publisher?

    internal var objectWillChange: ObservableObjectPublisher?

    /// The property that can be accessed with the `$` syntax and allows access to
    /// the `Publisher`
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

    // swiftlint:disable let_var_whitespace
    @available(*, unavailable, message: """
               @Published is only available on properties of classes
               """)
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() } // swiftlint:disable:this unused_setter_value
    }
    // swiftlint:enable let_var_whitespace

    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Published<Value>>
    ) -> Value {
        get {
            return object[keyPath: storageKeyPath].value
        }
        set {
            object[keyPath: storageKeyPath].objectWillChange?.send()
            object[keyPath: storageKeyPath].publisher?.subject.send(newValue)
            object[keyPath: storageKeyPath].value = newValue
        }
        // TODO: Benchmark and explore a possibility to use _modify
    }
}
#else

@available(swift, introduced: 5.1)
public typealias Published = Never

#endif // swift(>=5.1)
