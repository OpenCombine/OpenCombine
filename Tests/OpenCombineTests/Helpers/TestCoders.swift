//
//  TestCoders.swift
//  
//
//  Created by Joseph Spadafora on 7/1/19.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

class TestEncoder: TopLevelEncoder {
    typealias Output = Int

    private var nextEncoded = 1

    var encoded: [Int: Any] = [:]

    var handleEncode: ((Any) -> Int?)?

    func encode<EncodableType: Encodable>(_ value: EncodableType) throws -> Int {
        var keyNumber = nextEncoded
        if let number = handleEncode?(value) {
            keyNumber = number
        } else {
            nextEncoded += 1
        }
        encoded[keyNumber] = value
        return keyNumber
    }
}

class TestDecoder: TopLevelDecoder {
    typealias Input = Int

    static let error = "Could not decode" as TestingError

    var handleDecode: ((Int) -> Any?)?

    func decode<DecodablyType: Decodable>(
        _ type: DecodablyType.Type,
        from data: Int)
        throws -> DecodablyType
    {
        if let value = handleDecode?(data), let mappedValue = value as? DecodablyType {
            return mappedValue
        }
        throw TestDecoder.error
    }
}
