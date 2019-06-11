//
//  Cancelable.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A protocol indicating that an activity or action may be canceled.
///
/// Calling `cancel()` frees up any allocated resources. It also stops side effects such as timers, network access,
/// or disk I/O.
public protocol Cancellable {

    /// Cancel the activity.
    func cancel()
}

/// A type-erasing cancellable object that executes a provided closure when canceled.
///
/// Subscriber implementations can use this type to provide a “cancellation token” that makes it possible for a caller
/// to cancel a publisher, but not to use the `Subscription` object to request items.
public final class AnyCancellable: Cancellable {

    private let _cancel: () -> Void

    /// Initializes the cancellable object with the given cancel-time closure.
    ///
    /// - Parameter cancel: A closure that the `cancel()` method executes.
    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }

    public init<C: Cancellable>(_ canceller: C) {
        _cancel = canceller.cancel
    }

    /// Cancel the activity.
    public func cancel() {
        _cancel()
    }
}
