//
//  ConnectablePublisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

/// A publisher that provides an explicit means of connecting and canceling publication.
///
/// Use `makeConnectable()` to create a `ConnectablePublisher` from any publisher whose
/// failure type is `Never`.
public protocol ConnectablePublisher: Publisher {

    /// Connects to the publisher and returns a `Cancellable` instance with which
    /// to cancel publishing.
    ///
    /// - Returns: A `Cancellable` instance that can be used to cancel publishing.
    func connect() -> Cancellable
}
