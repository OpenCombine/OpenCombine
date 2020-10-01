//
//  Published.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 01/09/2019.
//

#if swift(>=5.1)
/// A type that publishes a property marked with an attribute.
///
/// Publishing a property with the `@Published` attribute creates a publisher of this
/// type. You access the publisher with the `$` operator, as shown here:
///
///     class Weather {
///         @Published var temperature: Double
///         init(temperature: Double) {
///             self.temperature = temperature
///         }
///     }
///
///     let weather = Weather(temperature: 20)
///     cancellable = weather.$temperature
///         .sink() {
///             print ("Temperature now: \($0)")
///         }
///     weather.temperature = 25
///
///     // Prints:
///     // Temperature now: 20.0
///     // Temperature now: 25.0
///
/// When the property changes, publishing occurs in the property's `willSet` block,
/// meaning subscribers receive the new value before it's actually set on the property.
/// In the above example, the second time the sink executes its closure, it receives
/// the parameter value `25`. However, if the closure evaluated `weather.temperature`,
/// the value returned would be `20`.
///
/// > Important: The `@Published` attribute is class constrained. Use it with properties
/// of classes, not with non-class types like structures.
///
/// ### See Also
///
/// - `Publisher.assign(to:)`
@available(swift, introduced: 5.1)
@propertyWrapper
public struct Published<Value> {

    /// Creates the published instance with an initial wrapped value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Published` attribute, as shown here:
    ///
    ///     @Published var lastUpdated: Date = Date()
    ///
    /// - Parameter wrappedValue: The publisher's initial value.
    @inlinable // trivially forwarding
    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }

    /// Creates the published instance with an initial value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Published` attribute, as shown here:
    ///
    ///     @Published var lastUpdated: Date = Date()
    ///
    /// - Parameter initialValue: The publisher's initial value.
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

    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
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
