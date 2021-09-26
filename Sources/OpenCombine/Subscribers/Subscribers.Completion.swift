//
//  Subscribers.Completion.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

#if canImport(_Concurrency)
import _Concurrency
#endif

extension Subscribers {

    /// A signal that a publisher doesn’t produce additional elements, either due to
    /// normal completion or an error.
    public enum Completion<Failure: Error> {

        /// The publisher finished normally.
        case finished

        /// The publisher stopped publishing due to the indicated error.
        case failure(Failure)
    }
}

extension Subscribers.Completion: Equatable where Failure: Equatable {}

extension Subscribers.Completion: Hashable where Failure: Hashable {}

// TODO: Uncomment when macOS 12 is released
#if canImport(_Concurrency) /* || compiler(>=5.5.x) */
extension Subscribers.Completion: Sendable {}
#endif

extension Subscribers.Completion {
    private enum CodingKeys: String, CodingKey {
        case success = "success"
        case error = "error"
    }
}

extension Subscribers.Completion: Encodable where Failure: Encodable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .finished:
            try container.encode(true, forKey: .success)
        case .failure(let error):
            try container.encode(false, forKey: .success)
            try container.encode(error, forKey: .error)
        }
    }
}

extension Subscribers.Completion: Decodable where Failure: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let success = try container.decode(Bool.self, forKey: .success)
        if success {
            self = .finished
        } else {
            let error = try container.decode(Failure.self, forKey: .error)
            self = .failure(error)
        }
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

    internal var failure: Failure? {
        switch self {
        case .finished:
            return nil
        case .failure(let failure):
            return failure
        }
    }
}
