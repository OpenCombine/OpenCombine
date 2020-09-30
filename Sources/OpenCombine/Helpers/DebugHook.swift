//
//  DebugHook.swift
//  
//
//  Created by Sergej Jaskiewicz on 27.09.2020.
//

internal final class DebugHook {

    private struct Handler: Hashable {
        let handler: _Introspection

        static func == (lhs: Handler, rhs: Handler) -> Bool {
            return lhs.handler === rhs.handler
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(handler))
        }
    }

    internal static func getGlobalHook() -> DebugHook? {
        globalLock.lock()
        defer { globalLock.unlock() }
        return globalHook
    }

    internal static func enable(_ handler: _Introspection) {
        let hook: DebugHook
        DebugHook.globalLock.lock()
        defer { DebugHook.globalLock.unlock() }
        if let _hook = DebugHook.globalHook {
            hook = _hook
        } else {
            hook = DebugHook()
            DebugHook.globalHook = hook
        }
        hook.lock.lock()
        defer { hook.lock.unlock() }
        hook.handlers.insert(Handler(handler: handler))
    }

    internal static func disable(_ handler: _Introspection) {
        DebugHook.globalLock.lock()
        defer { DebugHook.globalLock.unlock() }
        guard let hook = DebugHook.globalHook else { return }
        hook.lock.lock()
        hook.handlers.remove(Handler(handler: handler))
        let noMoreHandlers = hook.handlers.isEmpty
        hook.lock.unlock()
        if noMoreHandlers {
            DebugHook.globalHook = nil
        }
    }

    internal static func handlerIsEnabled(_ handler: _Introspection) -> Bool {
        DebugHook.globalLock.lock()
        defer { DebugHook.globalLock.unlock() }
        guard let hook = DebugHook.globalHook else { return false }
        hook.lock.lock()
        defer { hook.lock.unlock() }
        return hook.handlers.contains(Handler(handler: handler))
    }

    private static var globalHook: DebugHook?

    private static let globalLock = UnfairLock.allocate()

    private let lock = UnfairLock.allocate()

    private var handlers = Set<Handler>()

    internal var debugHandlers: [_Introspection] {
        lock.lock()
        defer { lock.unlock() }
        return handlers.map { $0.handler }
    }

    private init() {}

    deinit {
        lock.deallocate()
    }

    internal func willReceive<Upstream: Publisher, Downstream: Subscriber>(
        publisher: Upstream,
        subscriber: Downstream
    ) where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input {
        for debugHandler in debugHandlers {
            debugHandler.willReceive(publisher: publisher, subscriber: subscriber)
        }
    }

    internal func didReceive<Upstream: Publisher, Downstream: Subscriber>(
        publisher: Upstream,
        subscriber: Downstream
    ) where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input {
        for debugHandler in debugHandlers {
            debugHandler.didReceive(publisher: publisher, subscriber: subscriber)
        }
    }

    internal func willReceive<Downstream: Subscriber>(subscriber: Downstream,
                                                      subscription: Subscription) {
        for debugHandler in debugHandlers {
            debugHandler.willReceive(subscriber: subscriber, subscription: subscription)
        }
    }

    internal func didReceive<Downstream: Subscriber>(subscriber: Downstream,
                                                     subscription: Subscription) {
        for debugHandler in debugHandlers {
            debugHandler.didReceive(subscriber: subscriber, subscription: subscription)
        }
    }

    internal func willReceive<Downstream: Subscriber>(subscriber: Downstream,
                                                      input: Downstream.Input) {
        for debugHandler in debugHandlers {
            debugHandler.willReceive(subscriber: subscriber, input: input)
        }
    }

    internal func didReceive<Downstream: Subscriber>(
        subscriber: Downstream,
        input: Downstream.Input,
        resultingDemand: Subscribers.Demand
    ) {
        for debugHandler in debugHandlers {
            debugHandler.didReceive(subscriber: subscriber,
                                    input: input,
                                    resultingDemand: resultingDemand)
        }
    }

    internal func willReceive<Downstream: Subscriber>(
        subscriber: Downstream,
        completion: Subscribers.Completion<Downstream.Failure>
    ) {
        for debugHandler in debugHandlers {
            debugHandler.willReceive(subscriber: subscriber, completion: completion)
        }
    }

    internal func didReceive<Downstream: Subscriber>(
        subscriber: Downstream,
        completion: Subscribers.Completion<Downstream.Failure>
    ) {
        for debugHandler in debugHandlers {
            debugHandler.didReceive(subscriber: subscriber, completion: completion)
        }
    }

    internal func willRequest(subscription: Subscription, demand: Subscribers.Demand) {
        for debugHandler in debugHandlers {
            debugHandler.willRequest(subscription: subscription, demand)
        }
    }

    internal func didRequest(subscription: Subscription, demand: Subscribers.Demand) {
        for debugHandler in debugHandlers {
            debugHandler.didRequest(subscription: subscription, demand)
        }
    }

    internal func willCancel(subscription: Subscription) {
        for debugHandler in debugHandlers {
            debugHandler.willCancel(subscription: subscription)
        }
    }

    internal func didCancel(subscription: Subscription) {
        for debugHandler in debugHandlers {
            debugHandler.didCancel(subscription: subscription)
        }
    }
}
