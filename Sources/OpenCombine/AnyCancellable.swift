//
//  AnyCancellable.swift
//
//
//  Created by Sergej Jaskiewicz on 26.06.2019.
//

/// A type-erasing cancellable object that executes a provided closure when canceled.
///
/// Subscriber implementations can use this type to provide a “cancellation token” that
/// makes it possible for a caller to cancel a publisher, but not to use the
/// `Subscription` object to request items.
public final class AnyCancellable: Cancellable, Hashable {

    private var _cancel: (() -> Void)?

    /// Initializes the cancellable object with the given cancel-time closure.
    ///
    /// - Parameter cancel: A closure that the `cancel()` method executes.
    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }

    public init<OtherCancellable: Cancellable>(_ canceller: OtherCancellable) {
        _cancel = canceller.cancel
    }

    public func cancel() {
        _cancel?()
        _cancel = nil
    }

    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    deinit {
        _cancel?()
    }
}

extension AnyCancellable {

    /// Stores this AnyCancellable in the specified collection.
    /// Parameters:
    ///    - collection: The collection to store this AnyCancellable.
    public func store<Cancellables: RangeReplaceableCollection>(
        in collection: inout Cancellables
    ) where Cancellables.Element == AnyCancellable {
        collection.append(self)
    }

    /// Stores this AnyCancellable in the specified set.
    /// Parameters:
    ///    - collection: The set to store this AnyCancellable.
    public func store(in set: inout Set<AnyCancellable>) {
        set.insert(self)
    }
}
