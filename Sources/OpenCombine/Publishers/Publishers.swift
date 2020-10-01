//
//  Publishers.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

/// A namespace for types that serve as publishers.
///
/// The various operators defined as extensions on `Publisher` implement their
/// functionality as classes or structures that extend this enumeration.
/// For example, the `contains(_:)` operator returns a `Publishers.Contains` instance.
public enum Publishers {}
