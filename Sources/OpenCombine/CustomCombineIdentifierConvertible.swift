//
//  CustomCombineIdentifierConvertible.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A protocol for uniquely identifying publisher streams.
///
/// If you create a custom `Subscription` or `Subscriber` type, implement this protocol
/// so that development tools can uniquely identify publisher chains in your app.
/// If your type is a class, OpenCombine provides an implementation of `combineIdentifier`
/// for you.
/// If your type is a structure, set up the identifier as follows:
///
///     let combineIdentifier = CombineIdentifier()
public protocol CustomCombineIdentifierConvertible {

    /// A unique identifier for identifying publisher streams.
    var combineIdentifier: CombineIdentifier { get }
}

extension CustomCombineIdentifierConvertible where Self: AnyObject {

    public var combineIdentifier: CombineIdentifier {
        return CombineIdentifier(self)
    }
}
