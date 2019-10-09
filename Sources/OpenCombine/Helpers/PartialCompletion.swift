//
//  PartialCompletion.swift
//  
//
//  Created by Sergej Jaskiewicz on 22.09.2019.
//

/// A value of this type is returned by the overridden `receive(newValue:)` method
/// of the `ReduceProducer` and `FilterProducer` classes.
internal enum PartialCompletion<Value, Failure: Error> {

    /// Indicate that we should continue accepting the upstream's output.
    case `continue`(Value)

    /// Indicate that no values should be received from the upstream anymore.
    case finished

    /// Indicate that there was a failure and we should send it downstream.
    case failure(Failure)
}

extension PartialCompletion where Value == Void {

    /// Indicate that we should continue accepting the upstream's output.
    internal static var `continue`: PartialCompletion { return .continue(()) }
}
