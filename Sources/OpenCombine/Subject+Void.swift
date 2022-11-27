//
//  Subject+Void.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

extension Subject where Output == Void {

    /// Sends a void value to the subscriber.
    ///
    /// Use `Void` inputs and outputs when you want to signal that an event has occurred,
    /// but don’t need to send the event itself.
    public func send() {
        send(())
    }
}
