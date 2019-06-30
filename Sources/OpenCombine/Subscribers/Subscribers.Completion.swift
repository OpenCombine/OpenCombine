//
//  Subscribers.Completion.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

extension Subscribers {

    /// A signal that a publisher doesn’t produce additional elements, either due
    /// to normal completion or an error.
    ///
    /// - `finished`: The publisher finished normally.
    /// - `failure`: The publisher stopped publishing due to the indicated error.
    public enum Completion<Failure: Error> {

        case finished

        case failure(Failure)
    }
}

extension Subscribers.Completion {

    /// Erases the `Failure` type to `Swift.Error`. This function exists
    /// because in Swift user-defined generic types are always
    /// [invariant](https://en.wikipedia.org/wiki/Covariance_and_contravariance_(computer_science)).
    internal func eraseError() -> Subscribers.Completion<Error> {
        switch self {
        case .finished:
            return .finished
        case .failure(let error):
            return .failure(error)
        }
    }
}
