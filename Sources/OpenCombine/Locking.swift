//
//  Locking.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

// The contents of this file are taken from the swift-corelibs-foundation project
// (https://github.com/apple/swift-corelibs-foundation/blob/master/Foundation/NSLock.swift)
// with slight modifications.
//
// We don't want to depend on Foundation.

#if os(Windows)
import WinSDK
#elseif canImport(Darwin)
import Darwin
#else
import Glibc
#endif

#if os(Windows)
private typealias MutexPointer = UnsafeMutablePointer<SRWLOCK>
private typealias RecursiveMutexPointer = UnsafeMutablePointer<CRITICAL_SECTION>
private typealias ConditionVariablePointer = UnsafeMutablePointer<CONDITION_VARIABLE>
#elseif CYGWIN
private typealias MutexPointer = UnsafeMutablePointer<pthread_mutex_t?>
private typealias RecursiveMutexPointer = UnsafeMutablePointer<pthread_mutex_t?>
private typealias ConditionVariablePointer = UnsafeMutablePointer<pthread_cond_t?>
#else
private typealias MutexPointer = UnsafeMutablePointer<pthread_mutex_t>
private typealias RecursiveMutexPointer = UnsafeMutablePointer<pthread_mutex_t>
private typealias ConditionVariablePointer = UnsafeMutablePointer<pthread_cond_t>
#endif

internal final class RecursiveLock {
    internal var mutex = RecursiveMutexPointer.allocate(capacity: 1)

    #if os(macOS) || os(iOS) || os(Windows)
    private var timeoutCond = ConditionVariablePointer.allocate(capacity: 1)
    private var timeoutMutex = MutexPointer.allocate(capacity: 1)
    #endif

    internal init() {
        #if os(Windows)
        InitializeCriticalSection(mutex)
        InitializeConditionVariable(timeoutCond)
        InitializeSRWLock(timeoutMutex)
        #else
        #if CYGWIN
        var attrib : pthread_mutexattr_t? = nil
        #else
        var attrib = pthread_mutexattr_t()
        #endif
        withUnsafeMutablePointer(to: &attrib) { attrs in
            pthread_mutexattr_init(attrs)
            pthread_mutexattr_settype(attrs, Int32(PTHREAD_MUTEX_RECURSIVE))
            pthread_mutex_init(mutex, attrs)
        }
        #if os(macOS) || os(iOS)
        pthread_cond_init(timeoutCond, nil)
        pthread_mutex_init(timeoutMutex, nil)
        #endif
        #endif
    }

    deinit {
        #if os(Windows)
        DeleteCriticalSection(mutex)
        #else
        pthread_mutex_destroy(mutex)
        #endif
        mutex.deinitialize(count: 1)
        mutex.deallocate()
        #if os(macOS) || os(iOS) || os(Windows)
        deallocateTimedLockData(cond: timeoutCond, mutex: timeoutMutex)
        #endif
    }

    private func lock() {
        #if os(Windows)
        EnterCriticalSection(mutex)
        #else
        pthread_mutex_lock(mutex)
        #endif
    }

    private func unlock() {
        #if os(Windows)
        LeaveCriticalSection(mutex)
        AcquireSRWLockExclusive(timeoutMutex)
        WakeAllConditionVariable(timeoutCond)
        ReleaseSRWLockExclusive(timeoutMutex)
        #else
        pthread_mutex_unlock(mutex)
        #if os(macOS) || os(iOS)
        // Wakeup any threads waiting in lock(before:)
        pthread_mutex_lock(timeoutMutex)
        pthread_cond_broadcast(timeoutCond)
        pthread_mutex_unlock(timeoutMutex)
        #endif
        #endif
    }

    internal func `do`<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}

private func deallocateTimedLockData(cond: ConditionVariablePointer,
                                     mutex: MutexPointer) {
    #if os(Windows)
    // CONDITION_VARIABLEs do not need to be explicitly destroyed
    #else
    pthread_cond_destroy(cond)
    #endif
    cond.deinitialize(count: 1)
    cond.deallocate()

    #if os(Windows)
    // SRWLOCKs do not need to be explicitly destroyed
    #else
    pthread_mutex_destroy(mutex)
    #endif
    mutex.deinitialize(count: 1)
    mutex.deallocate()
}
