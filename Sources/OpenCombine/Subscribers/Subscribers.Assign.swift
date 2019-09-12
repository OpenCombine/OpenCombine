//
//  Subscribers.Assign.swift
//  
//
//  Created by Sergej Jaskiewicz on 15.06.2019.
//

extension Subscribers {

    public final class Assign<Root, Input>: Subscriber,
                                            Cancellable,
                                            CustomStringConvertible,
                                            CustomReflectable,
                                            CustomPlaygroundDisplayConvertible
    {
        public typealias Failure = Never

        public private(set) var object: Root?

        public let keyPath: ReferenceWritableKeyPath<Root, Input>

        private var _upstreamSubscription: Subscription?

        public var description: String { return "Assign \(Root.self)." }

        public var customMirror: Mirror {
            let children: [(label: String?, value: Any)] = [
                (label: "object", value: object as Any),
                (label: "keyPath", value: keyPath),
                (label: "status", value: _upstreamSubscription as Any)
            ]
            return Mirror(self, children: children)
        }

        public var playgroundDescription: Any { return description }

        public init(object: Root, keyPath: ReferenceWritableKeyPath<Root, Input>) {
            self.object = object
            self.keyPath = keyPath
        }

        public func receive(subscription: Subscription) {
            if _upstreamSubscription == nil {
                _upstreamSubscription = subscription
                subscription.request(.unlimited)
            } else {
                subscription.cancel()
            }
        }

        public func receive(_ value: Input) -> Subscribers.Demand {
            if _upstreamSubscription != nil {
                object?[keyPath: keyPath] = value
            }
            return .none
        }

        public func receive(completion: Subscribers.Completion<Never>) {
            cancel()
        }

        public func cancel() {
            _upstreamSubscription?.cancel()
            _upstreamSubscription = nil
            object = nil
        }
    }
}

extension Publisher where Self.Failure == Never {

    /// Assigns each element from a Publisher to a property on an object.
    ///
    /// - Parameters:
    ///   - keyPath: The key path of the property to assign.
    ///   - object: The object on which to assign the value.
    /// - Returns: A cancellable instance; used when you end assignment
    ///   of the received value. Deallocation of the result will tear down
    ///   the subscription stream.
    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Output>,
                             on object: Root) -> AnyCancellable {
        let subscriber = Subscribers.Assign(object: object, keyPath: keyPath)
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
