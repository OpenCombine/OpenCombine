//
//  CustomCombineIdentifierConvertible.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

public protocol CustomCombineIdentifierConvertible {

    var combineIdentifier: CombineIdentifier { get }
}

extension CustomCombineIdentifierConvertible where Self: AnyObject {

    public var combineIdentifier: CombineIdentifier {
        return CombineIdentifier(self)
    }
}
