//
//  Cancelable.swift
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
