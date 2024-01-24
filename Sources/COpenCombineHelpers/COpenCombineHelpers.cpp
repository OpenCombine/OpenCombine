//
//  COpenCombineHelpers.cpp
//  
//
//  Created by Sergej Jaskiewicz on 23/09/2019.
//

#include "COpenCombineHelpers.h"

#include <atomic>
#include <cstdlib>
#include <system_error>

#if __has_include(<pthread.h>)
#  include <pthread.h>
#  define OPENCOMBINE_HAS_PTHREAD 1
#else
#  define OPENCOMBINE_HAS_PTHREAD 0
#endif

#if __has_include(<signal.h>)
#  include <signal.h>
#  define OPENCOMBINE_HAS_SIGNAL_HANDLING 1
#else
#  define OPENCOMBINE_HAS_SIGNAL_HANDLING 0
#endif

#ifdef _WIN32
#  include <windows.h>
#endif

#ifdef __APPLE__
#include <os/lock.h>
#endif // __APPLE__

#include <mutex>

// Throwing exceptions through language boundaries is undefined behavior,
// so we must catch all of them in our extern "C" functions.
#define OPENCOMBINE_HANDLE_EXCEPTION_BEGIN try {

// std::terminate will print the type and the error message of the in-flight exception.
#define OPENCOMBINE_HANDLE_EXCEPTION_END } catch (...) { std::terminate(); }

// See 'double expansion trick'
#define OPENCOMBINE_STRINGIFY(value) #value
#define OPENCOMBINE_STRINGIFY_(value) OPENCOMBINE_STRINGIFY(value)
#define OPENCOMBINE_STRING_LINE_NUMBER OPENCOMBINE_STRINGIFY_(__LINE__)

// Throw an exception if the argument is non-zero with filename and line where the error
// occured.
#define OPENCOMBINE_HANDLE_PTHREAD_CALL(errc) \
    if ((errc) != 0) { \
        const char* what = __FILE__ ":" OPENCOMBINE_STRING_LINE_NUMBER ": " #errc; \
        throw std::system_error((errc), std::system_category(), what); \
    }

namespace {

std::atomic<uint64_t> next_combine_identifier;

class PlatformIndependentMutex {
public:
    virtual void lock() = 0;
    virtual void unlock() = 0;
    virtual void assertOwner() {}

    virtual ~PlatformIndependentMutex() {}
};

#if OPENCOMBINE_HAS_PTHREAD
class PThreadMutex final : PlatformIndependentMutex {
private:
    pthread_mutex_t mutex_;
public:
    PThreadMutex() {
        Attributes attrs;
        attrs.setErrorCheck();
        initialize(attrs);
    }

    PThreadMutex(const PThreadMutex&) = delete;
    PThreadMutex& operator=(const PThreadMutex&) = delete;

    PThreadMutex(PThreadMutex&&) = delete;
    PThreadMutex& operator=(PThreadMutex&&) = delete;

    void lock() override {
        OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutex_lock(&mutex_));
    }

    void unlock() override {
        OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutex_unlock(&mutex_));
    }

    ~PThreadMutex() {
        pthread_mutex_destroy(&mutex_);
    }
protected:
    class Attributes {
        pthread_mutexattr_t attrs_;
    public:
        Attributes() {
            OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutexattr_init(&attrs_));
        }

        Attributes(const Attributes&) = delete;
        Attributes& operator=(const Attributes&) = delete;

        Attributes(Attributes&&) = delete;
        Attributes& operator=(Attributes&&) = delete;

        const pthread_mutexattr_t* raw() const noexcept {
            return &attrs_;
        }

        void setRecursive() {
            setType(PTHREAD_MUTEX_RECURSIVE);
        }

        void setErrorCheck() {
            setType(PTHREAD_MUTEX_ERRORCHECK);
        }

        ~Attributes() {
            pthread_mutexattr_destroy(&attrs_);
        }
    private:
        void setType(int type) {
            OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutexattr_settype(&attrs_, type));
        }
    };

    void initialize(const Attributes& attributes) {
        OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutex_init(&mutex_, attributes.raw()));
    }
};
#endif // OPENCOMBINE_HAS_PTHREAD

#ifdef __APPLE__

class OS_UNFAIR_LOCK_AVAILABILITY OSUnfairLock final : PlatformIndependentMutex {
    os_unfair_lock mutex_ = OS_UNFAIR_LOCK_INIT;
public:
    OSUnfairLock() = default;

    OSUnfairLock(const OSUnfairLock&) = delete;
    OSUnfairLock& operator=(const OSUnfairLock&) = delete;

    OSUnfairLock(OSUnfairLock&&) = delete;
    OSUnfairLock& operator=(OSUnfairLock&&) = delete;

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

#ifdef OPENCOMBINE_OSLOCK_PRIVATE
class OS_UNFAIR_RECURSIVE_LOCK_AVAILABILITY OSUnfairRecursiveLock final : PlatformIndependentMutex {
    os_unfair_recursive_lock mutex_ = OS_UNFAIR_RECURSIVE_LOCK_INIT;
public:
    OSUnfairRecursiveLock() = default;

    OSUnfairRecursiveLock(const OSUnfairRecursiveLock&) = delete;
    OSUnfairRecursiveLock& operator=(const OSUnfairRecursiveLock&) = delete;

    OSUnfairRecursiveLock(OSUnfairRecursiveLock&&) = delete;
    OSUnfairRecursiveLock& operator=(OSUnfairRecursiveLock&&) = delete;

    void lock() override {
        os_unfair_recursive_lock_lock(&mutex_);
    }

    void unlock() override {
        os_unfair_recursive_lock_unlock(&mutex_);
    }

    void assertOwner() override {
        os_unfair_recursive_lock_assert_owner(&mutex_);
    }
};
#endif // OPENCOMBINE_OSLOCK_PRIVATE

#endif // __APPLE__

template <typename Mu>
class GenericMutex final : PlatformIndependentMutex {
    Mu mutex_;
public:

    GenericMutex() = default;

    GenericMutex(const GenericMutex&) = delete;
    GenericMutex& operator=(const GenericMutex&) = delete;

    GenericMutex(GenericMutex&&) = delete;
    GenericMutex& operator=(GenericMutex&&) = delete;

    void lock() override {
        mutex_.lock();
    }

    void unlock() override {
        mutex_.unlock();
    }
};

using StdMutex = GenericMutex<std::mutex>;
using StdRecursiveMutex = GenericMutex<std::recursive_mutex>;

} // end anonymous namespace

uint64_t opencombine_next_combine_identifier(void) {
    return next_combine_identifier.fetch_add(1);
}

OpenCombineUnfairLock opencombine_unfair_lock_alloc(void) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
#ifdef __APPLE__
    if (__builtin_available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)) {
        return {new OSUnfairLock};
    } else {
        return {new PThreadMutex};
    }
#elif OPENCOMBINE_HAS_PTHREAD
    // When possible, use pthread mutex implementation, because it allows
    // setting the PTHREAD_MUTEX_ERRORCHECK attribute, which makes
    // recursive locking a hard error instead of UB.
    return {new PThreadMutex};
#else
    return {new StdMutex};
#endif
    OPENCOMBINE_HANDLE_EXCEPTION_END
}

OpenCombineUnfairRecursiveLock opencombine_unfair_recursive_lock_alloc(void) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
#if defined(__APPLE__) && defined(OPENCOMBINE_OSLOCK_PRIVATE)
    if (__builtin_available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)) {
        return {new OSUnfairRecursiveLock};
    } else {
        return {new StdRecursiveMutex};
    }
#else
    return {new StdRecursiveMutex};
#endif
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

void opencombine_stop_in_debugger(void) {
#if _WIN32
    DebugBreak();
#elif OPENCOMBINE_HAS_SIGNAL_HANDLING
    raise(SIGTRAP);
#endif
}

bool opencombine_sanitize_address_enabled(void) {
    #if ASAN_ENABLED
    return true;
    #else
    return false;
    #endif
}

bool opencombine_sanitize_thread_enabled(void) {
    #if TSAN_ENABLED
    return true;
    #else
    return false;
    #endif
}

bool opencombine_sanitize_coverage_enabled(void) {
    #if COVERAGE_ENABLED
    return true;
    #else
    return false;
    #endif
}
