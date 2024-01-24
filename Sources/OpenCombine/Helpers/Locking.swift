//
//  Locking.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

#if canImport(COpenCombineHelpers)
@_implementationOnly import COpenCombineHelpers
#endif

#if os(WASI)
internal struct __UnfairLock { // swiftlint:disable:this type_name
    internal static func allocate() -> UnfairLock { return .init() }
    internal func lock() {}
    internal func unlock() {}
    internal func assertOwner() {}
    internal func deallocate() {}
}

internal struct __UnfairRecursiveLock { // swiftlint:disable:this type_name
    internal static func allocate() -> UnfairRecursiveLock { return .init() }
    internal func lock() {}
    internal func unlock() {}
    internal func deallocate() {}
}
#endif // os(WASI)

internal typealias UnfairLock = __UnfairLock
internal typealias UnfairRecursiveLock = __UnfairRecursiveLock
