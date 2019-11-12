//
//  TrackingEncoder.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.11.2019.
//

final class TrackingEncoder {

    enum Event: Equatable {
        // Encoder
        case getCodingPath
        case getUserInfo
        case containerKeyedBy
        case unkeyedContainer
        case singleValueContainer

        // KeyedEncodingContainerProtocol
        case keyedContainerCodingPath
        case keyedContainerEncodeNil(String)
        case keyedContainerEncodeBool(Bool, String)
        case keyedContainerEncodeString(String, String)
        case keyedContainerEncodeDouble(Double, String)
        case keyedContainerEncodeFloat(Float, String)
        case keyedContainerEncodeInt(Int, String)
        case keyedContainerEncodeInt8(Int8, String)
        case keyedContainerEncodeInt16(Int16, String)
        case keyedContainerEncodeInt32(Int32, String)
        case keyedContainerEncodeInt64(Int64, String)
        case keyedContainerEncodeUInt(UInt, String)
        case keyedContainerEncodeUInt8(UInt8, String)
        case keyedContainerEncodeUInt16(UInt16, String)
        case keyedContainerEncodeUInt32(UInt32, String)
        case keyedContainerEncodeUInt64(UInt64, String)
        case keyedContainerEncodeEncodable(String)
        case keyedContainerNestedKeyedContainer(String)
        case keyedContainerNestedUnkeyedContainer(String)
        case keyedContainerSuperEncoder
        case keyedContainerSuperEncoderForKey(String)

        // UnkeyedEncodingContainer
        case unkeyedContainerCodingPath
        case unkeyedContainerCount
        case unkeyedContainerEncodeNil
        case unkeyedContainerEncodeBool(Bool)
        case unkeyedContainerEncodeString(String)
        case unkeyedContainerEncodeDouble(Double)
        case unkeyedContainerEncodeFloat(Float)
        case unkeyedContainerEncodeInt(Int)
        case unkeyedContainerEncodeInt8(Int8)
        case unkeyedContainerEncodeInt16(Int16)
        case unkeyedContainerEncodeInt32(Int32)
        case unkeyedContainerEncodeInt64(Int64)
        case unkeyedContainerEncodeUInt(UInt)
        case unkeyedContainerEncodeUInt8(UInt8)
        case unkeyedContainerEncodeUInt16(UInt16)
        case unkeyedContainerEncodeUInt32(UInt32)
        case unkeyedContainerEncodeUInt64(UInt64)
        case unkeyedContainerEncodeEncodable
        case unkeyedContainerNestedKeyedContainer
        case unkeyedContainerNestedUnkeyedContainer
        case unkeyedContainerSuperEncoder

        // SingleValueEncodingContainer
        case singleValueContainerCodingPath
        case singleValueContainerEncodeNil
        case singleValueContainerEncodeBool(Bool)
        case singleValueContainerEncodeString(String)
        case singleValueContainerEncodeDouble(Double)
        case singleValueContainerEncodeFloat(Float)
        case singleValueContainerEncodeInt(Int)
        case singleValueContainerEncodeInt8(Int8)
        case singleValueContainerEncodeInt16(Int16)
        case singleValueContainerEncodeInt32(Int32)
        case singleValueContainerEncodeInt64(Int64)
        case singleValueContainerEncodeUInt(UInt)
        case singleValueContainerEncodeUInt8(UInt8)
        case singleValueContainerEncodeUInt16(UInt16)
        case singleValueContainerEncodeUInt32(UInt32)
        case singleValueContainerEncodeUInt64(UInt64)
        case singleValueContainerEncodeEncodable
    }

    fileprivate(set) var history: [Event] = []

    fileprivate var _codingPath: [CodingKey] = []

    fileprivate var _userInfo: [CodingUserInfoKey : Any] = [:]

    fileprivate var _unkeyedContainerCount = 0
}

extension TrackingEncoder: Encoder {

    var codingPath: [CodingKey] {
        history.append(.getCodingPath)
        return _codingPath
    }

    var userInfo: [CodingUserInfoKey : Any] {
        history.append(.getUserInfo)
        return _userInfo
    }

    func container<Key: CodingKey>(
        keyedBy type: Key.Type
    ) -> KeyedEncodingContainer<Key> {
        history.append(.containerKeyedBy)
        return .init(TrackingKeyedEncoder(encoder: self))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        history.append(.unkeyedContainer)
        return TrackingUnkeyedEncoder(encoder: self)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        history.append(.singleValueContainer)
        return TrackingSingleValueEncoder(encoder: self)
    }
}

private struct TrackingKeyedEncoder<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: TrackingEncoder

    var codingPath: [CodingKey] {
        encoder.history.append(.keyedContainerCodingPath)
        return encoder._codingPath
    }

    mutating func encodeNil(forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeNil(key.stringValue))
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeBool(value, key.stringValue))
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeString(value, key.stringValue))
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeDouble(value, key.stringValue))
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeFloat(value, key.stringValue))
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeInt(value, key.stringValue))
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeInt8(value, key.stringValue))
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeInt16(value, key.stringValue))
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeInt32(value, key.stringValue))
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeInt64(value, key.stringValue))
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeUInt(value, key.stringValue))
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeUInt8(value, key.stringValue))
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeUInt16(value, key.stringValue))
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeUInt32(value, key.stringValue))
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeUInt64(value, key.stringValue))
    }

    mutating func encode<Value: Encodable>(_ value: Value, forKey key: Key) throws {
        encoder.history.append(.keyedContainerEncodeEncodable(key.stringValue))
        try value.encode(to: encoder)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        encoder.history.append(.keyedContainerNestedKeyedContainer(key.stringValue))
        return .init(TrackingKeyedEncoder<NestedKey>(encoder: encoder))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        encoder.history.append(.keyedContainerNestedUnkeyedContainer(key.stringValue))
        return TrackingUnkeyedEncoder(encoder: encoder)
    }

    mutating func superEncoder() -> Encoder {
        encoder.history.append(.keyedContainerSuperEncoder)
        return encoder
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        encoder.history.append(.keyedContainerSuperEncoderForKey(key.stringValue))
        return encoder
    }
}

private struct TrackingUnkeyedEncoder: UnkeyedEncodingContainer {

    let encoder: TrackingEncoder

    var codingPath: [CodingKey] {
        encoder.history.append(.unkeyedContainerCodingPath)
        return encoder._codingPath
    }

    var count: Int {
        encoder.history.append(.unkeyedContainerCount)
        return encoder._unkeyedContainerCount
    }

    mutating func encodeNil() throws {
        encoder.history.append(.unkeyedContainerEncodeNil)
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: Bool) throws {
        encoder.history.append(.unkeyedContainerEncodeBool(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: String) throws {
        encoder.history.append(.unkeyedContainerEncodeString(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: Double) throws {
        encoder.history.append(.unkeyedContainerEncodeDouble(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: Float) throws {
        encoder.history.append(.unkeyedContainerEncodeFloat(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: Int) throws {
        encoder.history.append(.unkeyedContainerEncodeInt(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: Int8) throws {
        encoder.history.append(.unkeyedContainerEncodeInt8(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: Int16) throws {
        encoder.history.append(.unkeyedContainerEncodeInt16(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: Int32) throws {
        encoder.history.append(.unkeyedContainerEncodeInt32(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: Int64) throws {
        encoder.history.append(.unkeyedContainerEncodeInt64(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: UInt) throws {
        encoder.history.append(.unkeyedContainerEncodeUInt(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: UInt8) throws {
        encoder.history.append(.unkeyedContainerEncodeUInt8(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: UInt16) throws {
        encoder.history.append(.unkeyedContainerEncodeUInt16(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: UInt32) throws {
        encoder.history.append(.unkeyedContainerEncodeUInt32(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode(_ value: UInt64) throws {
        encoder.history.append(.unkeyedContainerEncodeUInt64(value))
        encoder._unkeyedContainerCount += 1
    }

    mutating func encode<Value: Encodable>(_ value: Value) throws {
        encoder.history.append(.unkeyedContainerEncodeEncodable)
        encoder._unkeyedContainerCount += 1
        try value.encode(to: encoder)
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        encoder.history.append(.unkeyedContainerNestedKeyedContainer)
        return .init(TrackingKeyedEncoder(encoder: encoder))
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        encoder.history.append(.unkeyedContainerNestedUnkeyedContainer)
        return self
    }

    func superEncoder() -> Encoder {
        encoder.history.append(.unkeyedContainerSuperEncoder)
        return encoder
    }
}

private struct TrackingSingleValueEncoder: SingleValueEncodingContainer {

    let encoder: TrackingEncoder

    var codingPath: [CodingKey] {
        encoder.history.append(.singleValueContainerCodingPath)
        return encoder._codingPath
    }

    mutating func encodeNil() throws {
        encoder.history.append(.singleValueContainerEncodeNil)
    }

    mutating func encode(_ value: Bool) throws {
        encoder.history.append(.singleValueContainerEncodeBool(value))
    }

    mutating func encode(_ value: String) throws {
        encoder.history.append(.singleValueContainerEncodeString(value))
    }

    mutating func encode(_ value: Double) throws {
        encoder.history.append(.singleValueContainerEncodeDouble(value))
    }

    mutating func encode(_ value: Float) throws {
        encoder.history.append(.singleValueContainerEncodeFloat(value))
    }

    mutating func encode(_ value: Int) throws {
        encoder.history.append(.singleValueContainerEncodeInt(value))
    }

    mutating func encode(_ value: Int8) throws {
        encoder.history.append(.singleValueContainerEncodeInt8(value))
    }

    mutating func encode(_ value: Int16) throws {
        encoder.history.append(.singleValueContainerEncodeInt16(value))
    }

    mutating func encode(_ value: Int32) throws {
        encoder.history.append(.singleValueContainerEncodeInt32(value))
    }

    mutating func encode(_ value: Int64) throws {
        encoder.history.append(.singleValueContainerEncodeInt64(value))
    }

    mutating func encode(_ value: UInt) throws {
        encoder.history.append(.singleValueContainerEncodeUInt(value))
    }

    mutating func encode(_ value: UInt8) throws {
        encoder.history.append(.singleValueContainerEncodeUInt8(value))
    }

    mutating func encode(_ value: UInt16) throws {
        encoder.history.append(.singleValueContainerEncodeUInt16(value))
    }

    mutating func encode(_ value: UInt32) throws {
        encoder.history.append(.singleValueContainerEncodeUInt32(value))
    }

    mutating func encode(_ value: UInt64) throws {
        encoder.history.append(.singleValueContainerEncodeUInt64(value))
    }

    mutating func encode<Value: Encodable>(_ value: Value) throws {
        encoder.history.append(.singleValueContainerEncodeEncodable)
        try value.encode(to: encoder)
    }
}
