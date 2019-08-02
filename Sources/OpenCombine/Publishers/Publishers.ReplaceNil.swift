//
//  Publishers.ReplaceNil.swift
//  
//
//  Created by Joseph Spadafora on 7/4/19.
//

extension Publisher {

    /// Replaces nil elements in the stream with the proviced element.
    ///
    /// - Parameter output: The element to use when replacing `nil`.
    /// - Returns: A publisher that replaces `nil` elements from
    /// the upstream publisher with the provided element.
    public func replaceNil<ElementOfResult>(
        with output: ElementOfResult
    ) -> Publishers.Map<Self, ElementOfResult>
        where Output == ElementOfResult?
    {
        return Publishers.Map(upstream: self) { $0 ?? output }
    }
}
