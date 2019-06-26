//
//  Subscribers.Completion.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

extension Subscribers {

    /// A signal that a publisher doesn’t produce additional elements, either due to normal completion or an error.
    ///
    /// - `finished`: The publisher finished normally.
    /// - `failure`: The publisher stopped publishing due to the indicated error.
    public enum Completion<Failure: Error> {

        case finished

        case failure(Failure)
    }
}
