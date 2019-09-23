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
internal protocol UnfairLock: AnyObject {
    func lock()
    func unlock()
}

extension UnfairLock {

    @inlinable
    internal func `do`<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}

internal protocol UnfairRecursiveLock: UnfairLock {}

internal func unfairLock() -> UnfairLock {
#if canImport(Darwin)
    if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
        return OSUnfairLock()
    } else {
        return PThreadMutexLock()
    }
#else
    return PThreadMutexLock()
#endif
}

internal func unfairRecursiveLock() -> UnfairRecursiveLock {
    // TODO: Use os_unfair_recursive_lock on Darwin as soon as it becomes public API.
    return PThreadMutexRecursiveLock()
}

private class PThreadMutexLock
    : UnfairLock,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
{
    private var mutex = pthread_mutex_t()

    init() {
        var status: Int32
        var attributes = pthread_mutexattr_t()
        status = pthread_mutexattr_init(&attributes)
        precondition(status == 0,
                     "pthread_mutexattr_init returned non-zero status: \(status)")

        // Enable error detection
        status = pthread_mutexattr_settype(&attributes, Int32(PTHREAD_MUTEX_ERRORCHECK))
        precondition(status == 0,
                     "pthread_mutexattr_settype returned non-zero status: \(status)")

        setAdditionalAttributes(&attributes)

        status = pthread_mutex_init(&mutex, &attributes)
        precondition(status == 0,
                     "pthread_mutex_init returned non-zero status: \(status)")
    }

    fileprivate func setAdditionalAttributes(
        _ attributes: UnsafeMutablePointer<pthread_mutexattr_t>
    ) {
        // Do nothing for non-recursive locks
    }

    final func lock() {
        let status = pthread_mutex_lock(&mutex)
        precondition(status == 0,
                     "pthread_mutex_lock returned non-zero status: \(status)")
    }

    final func unlock() {
        let status = pthread_mutex_unlock(&mutex)
        precondition(status == 0,
                     "pthread_mutex_lock returned non-zero status: \(status)")
    }

    final var description: String { return String(describing: mutex) }

    final var customMirror: Mirror { return Mirror(reflecting: mutex) }

    final var playgroundDescription: Any { return description }

    deinit {
        let status = pthread_mutex_destroy(&mutex)
        precondition(status == 0,
                     "pthread_mutex_destroy returned non-zero status: \(status)")
    }
}

private final class PThreadMutexRecursiveLock: PThreadMutexLock, UnfairRecursiveLock {
    override func setAdditionalAttributes(
        _ attributes: UnsafeMutablePointer<pthread_mutexattr_t>
    ) {
        let status = pthread_mutexattr_settype(attributes, Int32(PTHREAD_MUTEX_RECURSIVE))
        precondition(status == 0,
                     "pthread_mutexattr_settype returned non-zero status: \(status)")
    }
}

#if canImport(Darwin)

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
private final class OSUnfairLock
    : UnfairLock,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
{
    private var mutex = os_unfair_lock()

    func lock() {
        os_unfair_lock_lock(&mutex)
    }

    func unlock() {
        os_unfair_lock_unlock(&mutex)
    }

    var description: String { return String(describing: mutex) }

    var customMirror: Mirror { return Mirror(reflecting: mutex) }

    var playgroundDescription: Any { return description }
}

#endif // canImport(Darwin)
