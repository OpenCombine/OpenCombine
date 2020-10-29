//
//  Published.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 01/09/2019.
//

#if swift(>=5.1)

extension Publisher where Failure == Never {

    /// Republishes elements received from a publisher, by assigning them to a property
    /// marked as a publisher.
    ///
    /// Use this operator when you want to receive elements from a publisher and republish
    /// them through a property marked with the `@Published` attribute. The `assign(to:)`
    /// operator manages the life cycle of the subscription, canceling the subscription
    /// automatically when the `Published` instance deinitializes. Because of this,
    /// the `assign(to:)` operator doesn't return an `AnyCancellable` that you're
    /// responsible for like `assign(to:on:)` does.
    ///
    /// The example below shows a model class that receives elements from an internal
    /// `Timer.TimerPublisher`, and assigns them to a `@Published` property called
    /// `lastUpdated`:
    ///
    ///     class MyModel: ObservableObject {
    ///             @Published var lastUpdated: Date = Date()
    ///             init() {
    ///                  Timer.publish(every: 1.0, on: .main, in: .common)
    ///                      .autoconnect()
    ///                      .assign(to: $lastUpdated)
    ///             }
    ///         }
    ///
    /// If you instead implemented `MyModel` with `assign(to: lastUpdated, on: self)`,
    /// storing the returned `AnyCancellable` instance could cause a reference cycle,
    /// because the `Subscribers.Assign` subscriber would hold a strong reference
    /// to `self`. Using `assign(to:)` solves this problem.
    ///
    /// - Parameter published: A property marked with the `@Published` attribute, which
    ///   receives and republishes all elements received from the upstream publisher.
    public func assign(to published: inout Published<Output>.Publisher) {
        subscribe(PublishedSubscriber(published.subject))
    }
}

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

    /// A publisher for properties marked with the `@Published` attribute.
    public struct Publisher: OpenCombine.Publisher {

        public typealias Output = Value

        public typealias Failure = Never

        fileprivate let subject: PublishedSubject<Value>

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Value, Downstream.Failure == Never
        {
            subject.subscribe(subscriber)
        }

        fileprivate init(_ output: Output) {
            subject = .init(output)
        }
    }

    private enum Storage {
        case value(Value)
        case publisher(Publisher)
    }

    private var storage: Storage

    internal var objectWillChange: ObservableObjectPublisher? {
        get {
            switch storage {
            case .value:
                return nil
            case .publisher(let publisher):
                return publisher.subject.objectWillChange
            }
        }
        set {
            projectedValue.subject.objectWillChange = newValue
        }
    }

    /// Creates the published instance with an initial wrapped value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Published` attribute, as shown here:
    ///
    ///     @Published var lastUpdated: Date = Date()
    ///
    /// - Parameter wrappedValue: The publisher's initial value.
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
        storage = .value(wrappedValue)
    }

    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
    public var projectedValue: Publisher {
        mutating get {
            switch storage {
            case .value(let value):
                let publisher = Publisher(value)
                storage = .publisher(publisher)
                return publisher
            case .publisher(let publisher):
                return publisher
            }
        }
        set { // swiftlint:disable:this unused_setter_value
            switch storage {
            case .value(let value):
                storage = .publisher(Publisher(value))
            case .publisher:
                break
            }
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
            switch object[keyPath: storageKeyPath].storage {
            case .value(let value):
                return value
            case .publisher(let publisher):
                return publisher.subject.value
            }
        }
        set {
            switch object[keyPath: storageKeyPath].storage {
            case .value:
                object[keyPath: storageKeyPath].storage = .publisher(Publisher(newValue))
            case .publisher(let publisher):
                publisher.subject.value = newValue
            }
        }
        // TODO: Benchmark and explore a possibility to use _modify
    }
}
#else

@available(swift, introduced: 5.1)
public typealias Published = Never

#endif // swift(>=5.1)
