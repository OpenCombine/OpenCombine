//
//  Publishers.ReplaceNil.swift
//  
//
//  Created by Joseph Spadafora on 7/4/19.
//

import Foundation

// swiftlint:disable generic_type_name
// We need to disable this linting rule to maintain the same public api that as
// the original Combine interface
extension Publisher {

    /// Replaces nil elements in the stream with the proviced element.
    ///
    /// - Parameter output: The element to use when replacing `nil`.
    /// - Returns: A publisher that replaces `nil` elements from
    /// the upstream publisher with the provided element.
    public func replaceNil<T>(with output: T) -> Publishers.Map<Self, T>
        where Self.Output == T?
    {
        return Publishers.Map(upstream: self) { element -> T in
            element ?? output
        }
    }
}
