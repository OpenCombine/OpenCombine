//
//  Locking.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import COpenCombineHelpers

extension UnfairLock {

    @inlinable
    internal func `do`<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}

extension UnfairRecursiveLock {

    @inlinable
    internal func `do`<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
