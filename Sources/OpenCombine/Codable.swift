//
//  Codable.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

/// A type that defines methods for decoding.
public protocol TopLevelDecoder {

    /// The type this decoder accepts.
    associatedtype Input

    /// Decodes an instance of the indicated type.
    func decode<DecodablyType: Decodable>(_ type: DecodablyType.Type,
                                          from: Input) throws -> DecodablyType
}

/// A type that defines methods for encoding.
public protocol TopLevelEncoder {

    /// The type this encoder produces.
    associatedtype Output

    /// Encodes an instance of the indicated type.
    ///
    /// - Parameter value: The instance to encode.
    func encode<EncodableType: Encodable>(_ value: EncodableType) throws -> Output
}
