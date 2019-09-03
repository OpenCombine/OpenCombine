//
//  Published.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 01/09/2019.
//

#if swift(>=5.1)
@propertyWrapper public struct Published<Value> {

    /// Initialize the storage of the Published
    /// property as well as the corresponding `Publisher`.
    public init(initialValue: Value) {
        self.projectedValue = .init(initialValue)
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
        public func receive<SubscriberType>(subscriber: SubscriberType)
            where Value == SubscriberType.Input,
            SubscriberType: Subscriber,
            SubscriberType.Failure == Published<Value>.Publisher.Failure
        {
            subject.subscribe(subscriber)
        }

        fileprivate let subject: OpenCombine.CurrentValueSubject<Value, Never>

        fileprivate init(_ output: Output) {
            self.subject = .init(output)
        }

        fileprivate func send(_ input: Output) {
            subject.send(input)
        }
    }

    /// The property that can be accessed with the
    /// `$` syntax and allows access to the `Publisher`
    public let projectedValue: Published<Value>.Publisher

    public var wrappedValue: Value {
        get { projectedValue.subject.value }
        set { projectedValue.subject.value = newValue }
    }

    @available(*, unavailable)
    public init(wrappedValue: Value) {
        self.projectedValue = .init(wrappedValue)
    }

    /* Subscript template
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
    */
}
#endif
