//
//  Locking.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("How to do locking on this platform?")
#endif

@usableFromInline
internal final class Lock {

    @usableFromInline
    internal var _mutex = pthread_mutex_t()

    @inlinable
    internal init(recursive: Bool) {
        var attrib = pthread_mutexattr_t()
        pthread_mutexattr_init(&attrib)
        if recursive {
            pthread_mutexattr_settype(&attrib, Int32(PTHREAD_MUTEX_RECURSIVE))
        }
        pthread_mutex_init(&_mutex, &attrib)
    }

    @inlinable
    deinit {
        pthread_mutex_destroy(&_mutex)
    }

    @inlinable
    internal func lock() {
        pthread_mutex_lock(&_mutex)
    }

    @inlinable
    internal func unlock() {
        pthread_mutex_unlock(&_mutex)
    }

    @inlinable
    internal func `do`<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
