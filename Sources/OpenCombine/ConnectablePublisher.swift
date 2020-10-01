//
//  ConnectablePublisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

/// A publisher that provides an explicit means of connecting and canceling publication.
///
/// Use a `ConnectablePublisher` when you need to perform additional configuration or
/// setup prior to producing any elements.
///
/// This publisher doesn’t produce any elements until you call its `connect()` method.
///
/// Use `makeConnectable()` to create a `ConnectablePublisher` from any publisher whose
/// failure type is `Never`.
public protocol ConnectablePublisher: Publisher {

    /// Connects to the publisher, allowing it to produce elements, and returns
    /// an instance with which to cancel publishing.
    ///
    /// - Returns: A `Cancellable` instance that you use to cancel publishing.
    func connect() -> Cancellable
}
