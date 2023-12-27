//
//  Locking.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.12.2019.
//

#if canImport(COpenCombineHelpers)
@_implementationOnly import COpenCombineHelpers
#endif

import OpenCombine

internal typealias UnfairLock = __UnfairLock
internal typealias UnfairRecursiveLock = __UnfairRecursiveLock
