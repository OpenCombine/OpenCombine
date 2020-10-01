//
//  ObservableObject.swift
//  
//
//  Created by Sergej Jaskiewicz on 08/09/2019.
//

/// A type of object with a publisher that emits before the object has changed.
///
/// By default an `ObservableObject` synthesizes an `objectWillChange` publisher that
/// emits the changed value before any of its `@Published` properties changes.
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
///     cancellable = john.objectWillChange
///         .sink { _ in
///             print("\(john.age) will change")
///         }
///     print(john.haveBirthday())
///     // Prints "24 will change"
///     // Prints "25"
public protocol ObservableObject: AnyObject {

    /// The type of publisher that emits before the object has changed.
    associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher
        where ObjectWillChangePublisher.Failure == Never

    /// A publisher that emits before the object has changed.
    var objectWillChange: ObjectWillChangePublisher { get }
}

extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    // swiftlint:disable let_var_whitespace
#if swift(>=5.1)
    /// A publisher that emits before the object has changed.
    @available(*, unavailable, message: """
               The default implementation of objectWillChange is not available yet. \
               It's being worked on in \
               https://github.com/broadwaylamb/OpenCombine/pull/97
               """)
    public var objectWillChange: ObservableObjectPublisher {
        fatalError("unimplemented")
    }
#else
    public var objectWillChange: ObservableObjectPublisher {
        return ObservableObjectPublisher()
    }
#endif
    // swiftlint:enable let_var_whitespace
}

/// A publisher that publishes changes from observable objects.
public final class ObservableObjectPublisher: Publisher {

    public typealias Output = Void

    public typealias Failure = Never

    private let lock = UnfairLock.allocate()

    private var connections = Set<Conduit>()

    // TODO: Combine needs this for some reason
    private var identifier: ObjectIdentifier?

    /// Creates an observable object publisher instance.
    public init() {}

    deinit {
        lock.deallocate()
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Void, Downstream.Failure == Never
    {
        let inner = Inner(downstream: subscriber, parent: self)
        lock.lock()
        connections.insert(inner)
        lock.unlock()
        subscriber.receive(subscription: inner)
    }

    public func send() {
        lock.lock()
        let connections = self.connections
        lock.unlock()
        for connection in connections {
            connection.send()
        }
    }

    private func remove(_ conduit: Conduit) {
        lock.lock()
        connections.remove(conduit)
        lock.unlock()
    }
}

extension ObservableObjectPublisher {
    private class Conduit: Hashable {

        fileprivate func send() {
            abstractMethod()
        }

        fileprivate static func == (lhs: Conduit, rhs: Conduit) -> Bool {
            return lhs === rhs
        }

        fileprivate func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
    }

    private final class Inner<Downstream: Subscriber>
        : Conduit,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Void, Downstream.Failure == Never
    {
        private enum State {
            case initialized
            case active
            case terminal
        }

        private weak var parent: ObservableObjectPublisher?
        private let downstream: Downstream
        private let downstreamLock = UnfairRecursiveLock.allocate()
        private let lock = UnfairLock.allocate()
        private var state = State.initialized

        init(downstream: Downstream, parent: ObservableObjectPublisher) {
            self.parent = parent
            self.downstream = downstream
        }

        deinit {
            downstreamLock.deallocate()
            lock.deallocate()
        }

        override func send() {
            lock.lock()
            let state = self.state
            lock.unlock()
            if state == .active {
                downstreamLock.lock()
                _ = downstream.receive()
                downstreamLock.unlock()
            }
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            if state == .initialized {
                state = .active
            }
            lock.unlock()
        }

        func cancel() {
            lock.lock()
            state = .terminal
            lock.unlock()
            parent?.remove(self)
        }

        var description: String { return "ObservableObjectPublisher" }

        var customMirror: Mirror {
            let children = CollectionOfOne<Mirror.Child>(("downstream", downstream))
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any {
            return description
        }
    }
}
