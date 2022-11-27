//
//  Subscriber+Void.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

extension Subscriber where Input == Void {

    /// Tells the subscriber that a publisher of void elements is ready to receive further
    /// requests.
    ///
    /// Use `Void` inputs and outputs when you want to signal that an event has occurred,
    /// but don’t need to send the event itself.
    /// - Returns: A `Subscribers.Demand` instance indicating how many more elements
    /// the subscriber expects to receive.
    public func receive() -> Subscribers.Demand {
        return receive(())
    }
}
