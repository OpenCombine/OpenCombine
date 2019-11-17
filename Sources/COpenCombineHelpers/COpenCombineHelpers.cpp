//
//  COpenCombineHelpers.cpp
//  
//
//  Created by Sergej Jaskiewicz on 23/09/2019.
//

#include "COpenCombineHelpers.h"

#include <atomic>
#include <mutex>
#include <cstdlib>

#ifdef __APPLE__
#include <os/lock.h>
#endif // __APPLE__

#define OPENCOMBINE_HANDLE_EXCEPTION_BEGIN try {

#define OPENCOMBINE_HANDLE_EXCEPTION_END } catch (...) { abort(); }

namespace {

std::atomic<uint64_t> next_combine_identifier;

class PlatformIndependentMutex {
public:
    virtual void lock() = 0;
    virtual void unlock() = 0;
    virtual void assertOwner() {}

    virtual ~PlatformIndependentMutex() {}
};

template <typename Mutex>
class GenericMutex final : PlatformIndependentMutex {
    Mutex mutex_;
public:
    void lock() override {
        mutex_.lock();
    }

    void unlock() override {
        mutex_.unlock();
    }
};

#ifdef __APPLE__
bool isOSUnfairLockAvailable() {
    // We're linking weakly, so if we're back-deploying, this will be null.
    return os_unfair_lock_lock != nullptr;
}

template <>
class GenericMutex<os_unfair_lock> final : PlatformIndependentMutex {
    os_unfair_lock mutex_ = OS_UNFAIR_LOCK_INIT;
public:
    GenericMutex() = default;
    GenericMutex(const GenericMutex&) = delete;
    GenericMutex& operator=(const GenericMutex&) = delete;

    void lock() override {
        os_unfair_lock_lock(&mutex_);
    }

    void unlock() override {
        os_unfair_lock_unlock(&mutex_);
    }

    void assertOwner() override {
        os_unfair_lock_assert_owner(&mutex_);
    }
};
#endif // __APPLE__

} // end anonymous namespace

extern "C" {

uint64_t opencombine_next_combine_identifier(void) {
    return next_combine_identifier.fetch_add(1);
}

OpenCombineUnfairLock opencombine_unfair_lock_alloc(void) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN

#ifdef __APPLE__
    if (isOSUnfairLockAvailable()) {
        return {new GenericMutex<os_unfair_lock>};
    } else {
        return {new GenericMutex<std::mutex>};
    }
#else
    return {new GenericMutex<std::mutex>};
#endif

    OPENCOMBINE_HANDLE_EXCEPTION_END
}

OpenCombineUnfairRecursiveLock opencombine_unfair_recursive_lock_alloc(void) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
    // TODO: Use os_unfair_recursive_lock on Darwin as soon as it becomes public API.
    return {new GenericMutex<std::recursive_mutex>};
    OPENCOMBINE_HANDLE_EXCEPTION_END
}

void opencombine_unfair_lock_lock(OpenCombineUnfairLock lock) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
    static_cast<PlatformIndependentMutex*>(lock.opaque)->lock();
    OPENCOMBINE_HANDLE_EXCEPTION_END
}

void opencombine_unfair_lock_unlock(OpenCombineUnfairLock mutex) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
    static_cast<PlatformIndependentMutex*>(mutex.opaque)->unlock();
    OPENCOMBINE_HANDLE_EXCEPTION_END
}

void opencombine_unfair_lock_assert_owner(OpenCombineUnfairLock mutex) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
    static_cast<PlatformIndependentMutex*>(mutex.opaque)->assertOwner();
    OPENCOMBINE_HANDLE_EXCEPTION_END
}

void opencombine_unfair_recursive_lock_lock(OpenCombineUnfairRecursiveLock lock) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
    static_cast<PlatformIndependentMutex*>(lock.opaque)->lock();
    OPENCOMBINE_HANDLE_EXCEPTION_END
}

void opencombine_unfair_recursive_lock_unlock(OpenCombineUnfairRecursiveLock mutex) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
    static_cast<PlatformIndependentMutex*>(mutex.opaque)->unlock();
    OPENCOMBINE_HANDLE_EXCEPTION_END
}

void opencombine_unfair_lock_dealloc(OpenCombineUnfairLock lock) {
    return delete static_cast<PlatformIndependentMutex*>(lock.opaque);
}

void opencombine_unfair_recursive_lock_dealloc(OpenCombineUnfairRecursiveLock lock) {
    return delete static_cast<PlatformIndependentMutex*>(lock.opaque);
}

} // extern "C"
