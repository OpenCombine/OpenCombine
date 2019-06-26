//
//  AnyCancellable.swift
//
//
//  Created by Sergej Jaskiewicz on 26.06.2019.
//

/// A type-erasing cancellable object that executes a provided closure when canceled.
///
/// Subscriber implementations can use this type to provide a “cancellation token” that makes it possible for a caller
/// to cancel a publisher, but not to use the `Subscription` object to request items.
public final class AnyCancellable: Cancellable {

    private var _cancel: (() -> Void)?

    /// Initializes the cancellable object with the given cancel-time closure.
    ///
    /// - Parameter cancel: A closure that the `cancel()` method executes.
    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }

    public init<CancellableType: Cancellable>(_ canceller: CancellableType) {
        _cancel = canceller.cancel
    }

    public func cancel() {
        _cancel?()
        _cancel = nil
    }

    deinit {
        cancel()
    }
}
