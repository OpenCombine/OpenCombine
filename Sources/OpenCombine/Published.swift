//
//  Published.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 01/09/2019.
//

import Foundation

@propertyWrapper public struct Published<Value> {

    /// Initialize the storage of the Published property as well as the corresponding `Publisher`.
    public init(initialValue: Value) {
        self.value = initialValue
    }

    public struct Publisher : OpenCombine.Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Value

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Never

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where Value == S.Input, S : Subscriber, S.Failure == Published<Value>.Publisher.Failure {
            
            _passthrowObject.receive(subscriber: subscriber)
        }
        
        
        // MARK: - Private
        private var _passthrowObject = OpenCombine.PassthroughSubject<Value,Never>()
        
        public func send(_ input: Output) {
            _passthrowObject.send(input)
        }
    }

    /// The property that can be accessed with the `$` syntax and allows access to the `Publisher`
    public private(set) lazy var projectedValue: Published<Value>.Publisher = Published<Value>.Publisher()
    
    public var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            projectedValue.send(newValue)
        }
     }
    
    // MARK: - Private
    private var value: Value
    
    // For removing warning: Property wrapper's `init(initialValue:)` should be renamed to 'init(wrappedValue:)'; use of 'init(initialValue:)' is deprecated
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }
}
