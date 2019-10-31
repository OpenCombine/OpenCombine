//
//  TypeMetadata.swift
//  
//
//  Created by Sergej Jaskiewicz on 31.10.2019.
//

import COpenCombineHelpers

internal typealias FieldEnumerator =
    (_ fieldName: UnsafePointer<CChar>, _ fieldOffset: Int, _ fieldType: Any.Type) -> Bool

internal func enumerateFields(ofType type: Any.Type, enumerator: FieldEnumerator) {
    // In Swift 5.1 this `withoutActuallyEscaping` thing is not necessary,
    // but we support Swift 5.0.
    withoutActuallyEscaping(enumerator) { enumerator in
        var context = enumerator
        enumerateClassFields(
            typeMetadata: unsafeBitCast(type, to: UnsafeRawPointer.self),
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
