//
//  Result.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

extension Result {

    internal func tryMap<NewSuccess>(
        _ transform: (Success) throws -> NewSuccess
    ) -> Result<NewSuccess, Error> {
        switch self {
        case .success(let success):
            do {
                return try .success(transform(success))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    internal func unwrapOr(_ handleError: (Failure) -> Success) -> Success {
        switch self {
        case .success(let success):
            return success
        case .failure(let error):
            return handleError(error)
        }
    }

    internal func unwrapOr(_ handleError: @autoclosure () -> Success) -> Success {
        return unwrapOr { _ in handleError() }
    }
}

extension Result where Failure == Never {
    internal var success: Success {
        switch self {
        case .success(let success):
            return success
        }
    }
}
