//
//  NotificationCenter.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.10.2019.
//

import Foundation
import OpenCombine

extension NotificationCenter {

    /// A namespace for disambiguation when both OpenCombine and Foundation are imported.
    ///
    /// Foundation extends `NotificationCenter` with new methods and nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `NotificationCenter.Publisher`,
    /// because Swift is unable to understand which `Publisher`
    /// you're referring to — the one declared in Foundation or in OpenCombine.
    ///
    /// So you have to write `NotificationCenter.OCombine.Publisher`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public struct OCombine {

        public let center: NotificationCenter

        public init(_ center: NotificationCenter) {
            self.center = center
        }

        /// A publisher that emits elements when broadcasting notifications.
        public struct Publisher: OpenCombine.Publisher {

            public typealias Output = Notification

            public typealias Failure = Never

            /// The notification center this publisher uses as a source.
            public let center: NotificationCenter

            /// The name of notifications published by this publisher.
            public let name: Notification.Name

            /// The object posting the named notification.
            public let object: AnyObject?

            /// Creates a publisher that emits events when broadcasting notifications.
            ///
            /// - Parameters:
            ///   - center: The notification center to publish notifications for.
            ///   - name: The name of the notification to publish.
            ///   - object: The object posting the named notification. If `nil`,
            ///     the publisher emits elements for any object producing a notification
            ///     with the given name.
            public init(center: NotificationCenter,
                        name: Notification.Name,
                        object: AnyObject? = nil) {
                self.center = center
                self.name = name
                self.object = object
            }

            public func receive<Downstream: Subscriber>(subscriber: Downstream)
                where Downstream.Failure == Never, Downstream.Input == Notification
            {
                let subscription = Notification.Subscription(center: center,
                                                             name: name,
                                                             object: object,
                                                             downstream: subscriber)
                subscriber.receive(subscription: subscription)
            }
        }

        /// Returns a publisher that emits events when broadcasting notifications.
        ///
        /// - Parameters:
        ///   - name: The name of the notification to publish.
        ///   - object: The object posting the named notification. If `nil`, the publisher
        ///     emits elements for any object producing a notification with the given
        ///     name.
        /// - Returns: A publisher that emits events when broadcasting notifications.
        public func publisher(for name: Notification.Name,
                              object: AnyObject? = nil) -> Publisher {
            return .init(center: center, name: name, object: object)
        }
    }

#if !canImport(Combine)
    /// A publisher that emits elements when broadcasting notifications.
    public typealias Publisher = OCombine.Publisher
#endif
}

extension NotificationCenter {

    /// A namespace for disambiguation when both OpenCombine and Foundation are imported.
    ///
    /// Foundation extends `NotificationCenter` with new methods and nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `NotificationCenter.default.publisher(for: name)`,
    /// because Swift is unable to understand which `publisher` method
    /// you're referring to — the one declared in Foundation or in OpenCombine.
    ///
    /// So you have to write `NotificationCenter.default.ocombine.publisher(for: name)`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public var ocombine: OCombine { return .init(self) }

#if !canImport(Combine)
    /// Returns a publisher that emits events when broadcasting notifications.
    ///
    /// - Parameters:
    ///   - name: The name of the notification to publish.
    ///   - object: The object posting the named notification. If `nil`, the publisher
    ///     emits elements for any object producing a notification with the given name.
    /// - Returns: A publisher that emits events when broadcasting notifications.
    public func publisher(for name: Notification.Name,
                          object: AnyObject? = nil) -> OCombine.Publisher {
        return ocombine.publisher(for: name, object: object)
    }
#endif
}

extension NotificationCenter.OCombine.Publisher: Equatable {
    public static func == (lhs: NotificationCenter.OCombine.Publisher,
                           rhs: NotificationCenter.OCombine.Publisher) -> Bool {
        return lhs.center == rhs.center &&
               lhs.name == rhs.name &&
               lhs.object === rhs.object
    }
}

extension Notification {
    fileprivate final class Subscription<Downstream: Subscriber>
        : OpenCombine.Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Notification, Downstream.Failure == Never
    {
        private let lock = UnfairLock.allocate()

        fileprivate let downstreamLock = UnfairRecursiveLock.allocate()

        fileprivate var demand = Subscribers.Demand.none

        private var center: NotificationCenter?

        private let name: Name

        private var object: AnyObject?

        private var observation: AnyObject?

        fileprivate init(center: NotificationCenter,
                         name: Notification.Name,
                         object: AnyObject?,
                         downstream: Downstream) {
            self.center = center
            self.name = name
            self.object = object
            self.observation = center
                .addObserver(forName: name, object: object, queue: nil) { [weak self] in
                    self?.didReceiveNotification($0, downstream: downstream)
                }
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        private func didReceiveNotification(_ notification: Notification,
                                            downstream: Downstream) {
            lock.lock()
            guard demand > 0 else {
                lock.unlock()
                return
            }
            demand -= 1
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(notification)
            downstreamLock.unlock()
            lock.lock()
            demand += newDemand
            lock.unlock()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            self.demand += demand
            lock.unlock()
        }

        func cancel() {
            lock.lock()
            guard let center = self.center.take(),
                  let observation = self.observation.take()
            else {
                lock.unlock()
                return
            }
            self.object = nil
            lock.unlock()
            center.removeObserver(observation)
        }

        fileprivate var description: String { return "NotificationCenter Observer" }

        fileprivate var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("center", center as Any),
                ("name", name),
                ("object", object as Any),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }

        fileprivate var playgroundDescription: Any { return description }
    }
}
