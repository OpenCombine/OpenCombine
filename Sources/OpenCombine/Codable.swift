//
//  Codable.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

public protocol TopLevelDecoder {

    associatedtype Input

    func decode<T: Decodable>(_ type: T.Type, from: Input) throws -> T
}

public protocol TopLevelEncoder {

    associatedtype Output

    func encode<T: Encodable>(_ value: T) throws -> Self.Output
}

