//
//  Locking.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

#if os(WASI)
struct UnfairLock {
    public static func allocate() -> UnfairLock { return Self.init() }
    public func lock() {}
    public func unlock() {}
    public func assertOwner() {}
    public func deallocate() {}
}

struct UnfairRecursiveLock {
    public static func allocate() -> UnfairRecursiveLock { return Self.init() }
    public func lock() {}
    public func unlock() {}
    public func deallocate() {}
}
#else
internal typealias UnfairLock = __UnfairLock
internal typealias UnfairRecursiveLock = __UnfairRecursiveLock
#endif
