//
//  Codable.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

public protocol TopLevelDecoder {

    associatedtype Input

    func decode<DecodablyType: Decodable>(_ type: DecodablyType.Type,
                                          from: Input) throws -> DecodablyType
}

public protocol TopLevelEncoder {

    associatedtype Output

    func encode<EncodableType: Encodable>(_ value: EncodableType) throws -> Output
}
