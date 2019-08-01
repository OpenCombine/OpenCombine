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

final class TestEncoder: TopLevelEncoder {
    typealias Output = Int

    private var nextEncoded = 1

    var encoded: [Int : Any] = [:]

    var handleEncode: ((Any) throws -> Int?)?

    func encode<EncodableType: Encodable>(_ value: EncodableType) throws -> Int {
        var keyNumber = nextEncoded
        if let number = try handleEncode?(value) {
            keyNumber = number
        } else {
            nextEncoded += 1
        }
        encoded[keyNumber] = value
        return keyNumber
    }
}

final class TestDecoder: TopLevelDecoder {
    typealias Input = Int

    static let error = "Could not decode" as TestingError

    var handleDecode: ((Int) throws -> Any?)?

    func decode<Decodable: Swift.Decodable>(
        _ type: Decodable.Type,
        from data: Int
    ) throws -> Decodable {
        if let value = try handleDecode?(data), let mappedValue = value as? Decodable {
            return mappedValue
        }
        throw TestDecoder.error
    }
}
