//
//  EnumerateFields.swift
//  
//
//  Created by Sergej Jaskiewicz on 31.10.2019.
//

import COpenCombineHelpers

internal typealias FieldEnumerator =
    (_ fieldName: UnsafePointer<CChar>, _ fieldOffset: Int, _ fieldType: Any.Type) -> Bool

internal func enumerateFields(ofType type: Any.Type,
                              allowResilientSuperclasses: Bool,
                              enumerator: FieldEnumerator) {
    // A neat trick to pass a Swift closure where a C function pointer is expected.
    // (Unlike closures, function pointers cannot capture context)
    withoutActuallyEscaping(enumerator) { enumerator in
        var context = enumerator
        enumerateClassFields(
            typeMetadata: unsafeBitCast(type, to: UnsafeRawPointer.self),
            allowResilientSuperclasses: allowResilientSuperclasses,
            enumeratorContext: &context,
            enumerator: { rawContext, fieldName, fieldOffset, rawMetadataPtr in
                rawContext
                    .unsafelyUnwrapped
                    .assumingMemoryBound(to: FieldEnumerator.self)
                    .pointee(fieldName,
                             fieldOffset,
                             unsafeBitCast(rawMetadataPtr, to: Any.Type.self))
            })
    }
}
