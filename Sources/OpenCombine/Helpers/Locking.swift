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
    private let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)

    init() {
        var attributes = pthread_mutexattr_t()
        assertPThreadFunctionSucceeds(pthread_mutexattr_init(&attributes))
        // Enable error detection
        assertPThreadFunctionSucceeds(
            pthread_mutexattr_settype(&attributes, CInt(PTHREAD_MUTEX_ERRORCHECK))
        )
        setAdditionalAttributes(&attributes)
        assertPThreadFunctionSucceeds(pthread_mutex_init(mutex, &attributes))
    }

    fileprivate func setAdditionalAttributes(
        _ attributes: UnsafeMutablePointer<pthread_mutexattr_t>
    ) {
        // Do nothing for non-recursive locks
    }

    final func lock() {
        assertPThreadFunctionSucceeds(pthread_mutex_lock(mutex))
    }

    final func unlock() {
        assertPThreadFunctionSucceeds(pthread_mutex_unlock(mutex))
    }

    final var description: String { return String(describing: mutex.pointee) }

    final var customMirror: Mirror { return Mirror(reflecting: mutex.pointee) }

    final var playgroundDescription: Any { return description }

    deinit {
        assertPThreadFunctionSucceeds(pthread_mutex_destroy(mutex))
        mutex.deallocate()
    }
}

private final class PThreadMutexRecursiveLock: PThreadMutexLock, UnfairRecursiveLock {
    override func setAdditionalAttributes(
        _ attributes: UnsafeMutablePointer<pthread_mutexattr_t>
    ) {
        assertPThreadFunctionSucceeds(
            pthread_mutexattr_settype(attributes, CInt(PTHREAD_MUTEX_RECURSIVE))
        )
    }
}

private func assertPThreadFunctionSucceeds(_ returnCode: CInt,
                                           file: StaticString = #file,
                                           line: UInt = #line) {
    // swiftlint:disable inheritance_colon — false positive here
    let abbreviation: String
    switch returnCode {
    case 0:
        return
    case EINVAL:
        abbreviation = "EINVAL"
    case EBUSY:
        abbreviation = "EBUSY"
    case EAGAIN:
        abbreviation = "EAGAIN"
    case EDEADLK:
        abbreviation = "EDEADLK"
    case EPERM:
        abbreviation = "EPERM"
    case ENOMEM:
        abbreviation = "ENOMEM"
    default:
        abbreviation = "\(returnCode)"
    }
    // swiftlint:enable inheritance_colon

    preconditionFailure("A pthread call failed with error code \(abbreviation)",
                        file: file,
                        line: line)
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
