//
//  Cancellable.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A protocol indicating that an activity or action may be canceled.
///
/// Calling `cancel()` frees up any allocated resources. It also stops side effects such
/// as timers, network access, or disk I/O.
public protocol Cancellable {

    /// Cancel the activity.
    func cancel()
}

extension Cancellable {

    /// Stores this Cancellable in the specified collection.
    /// Parameters:
    ///    - collection: The collection to store this Cancellable.
    public func store<Cancellables: RangeReplaceableCollection>(
            in collection: inout Cancellables
    ) where Cancellables.Element == AnyCancellable {
        AnyCancellable(self).store(in: &collection)
    }

    /// Stores this Cancellable in the specified set.
    /// Parameters:
    ///    - collection: The set to store this Cancellable.
    public func store(in set: inout Set<AnyCancellable>) {
        AnyCancellable(self).store(in: &set)
    }
}
