//
//  TypeMetadata.swift
//  
//
//  Created by Sergej Jaskiewicz on 31.10.2019.
//

import COpenCombineHelpers

internal struct FieldInfo: Equatable, CustomDebugStringConvertible {
    let name: String
    let offset: Int
    let type: Any.Type

    init(_ name: String, _ offset: Int, _ type: Any.Type) {
        self.name = name
        self.offset = offset
        self.type = type
    }

    static func == (lhs: FieldInfo, rhs: FieldInfo) -> Bool {
        return lhs.name   == rhs.name   &&
               lhs.offset == rhs.offset &&
               lhs.type   == rhs.type
    }

    var debugDescription: String {
        return "(name: \(name.debugDescription), offset: \(offset), type: \(type).self)"
    }
}

internal typealias FieldEnumerator = (FieldInfo) -> Bool

internal func enumerateFields(ofType type: Any.Type,
                              allowResilientSuperclasses: Bool,
                              enumerator: FieldEnumerator) {
    withoutActuallyEscaping(enumerator) { enumerator in
        var context = enumerator
        enumerateClassFields(
            typeMetadata: unsafeBitCast(type, to: UnsafeRawPointer.self),
            allowResilientSuperclasses: allowResilientSuperclasses,
            enumeratorContext: &context,
            enumerator: { rawContext, fieldName, fieldOffset, rawMetadataPtr in
                let fieldInfo = FieldInfo(
                    String(cString: fieldName),
                    fieldOffset,
                    unsafeBitCast(rawMetadataPtr, to: Any.Type.self)
                )
                return rawContext
                    .unsafelyUnwrapped
                    .assumingMemoryBound(to: FieldEnumerator.self)
                    .pointee(fieldInfo)
            })
    }
}
