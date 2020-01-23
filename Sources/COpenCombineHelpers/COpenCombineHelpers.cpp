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
#include <pthread.h>
#include <signal.h>

#ifdef __APPLE__
#include <os/lock.h>
#endif // __APPLE__

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

    virtual ~PlatformIndependentMutex() noexcept(false) {}
};

class PThreadMutex : PlatformIndependentMutex {
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

    void lock() override final {
        OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutex_lock(&mutex_));
    }

    void unlock() override final {
        OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutex_unlock(&mutex_));
    }

    ~PThreadMutex() {
        // Yep, this destructor may throw. This is deliberate, since pthread_mutex_destroy
        // may fail.
        //
        // The altrenative is to just silently ignore the error, which is even worse.
        OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutex_destroy(&mutex_));
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

        ~Attributes() noexcept(false) {
            // Yep, this destructor may throw. This is deliberate,
            // since pthread_mutexattr_destroy may fail.
            //
            // The altrenative is to just silently ignore the error, which is even worse.
            OPENCOMBINE_HANDLE_PTHREAD_CALL(pthread_mutexattr_destroy(&attrs_));
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

class PThreadRecursiveMutex final : PThreadMutex {
public:
    PThreadRecursiveMutex() {
        Attributes attrs;
        attrs.setRecursive();
        initialize(attrs);
    }

    PThreadRecursiveMutex(const PThreadRecursiveMutex&) = delete;
    PThreadRecursiveMutex& operator=(const PThreadRecursiveMutex&) = delete;

    PThreadRecursiveMutex(PThreadRecursiveMutex&&) = delete;
    PThreadRecursiveMutex& operator=(PThreadRecursiveMutex&&) = delete;
};

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
#endif // __APPLE__

} // end anonymous namespace

extern "C" {

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
#else
    return {new PThreadMutex};
#endif

    OPENCOMBINE_HANDLE_EXCEPTION_END
}

OpenCombineUnfairRecursiveLock opencombine_unfair_recursive_lock_alloc(void) {
    OPENCOMBINE_HANDLE_EXCEPTION_BEGIN
    // TODO: Use os_unfair_recursive_lock on Darwin as soon as it becomes public API.
    return {new PThreadRecursiveMutex};
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
    raise(SIGTRAP);
}

} // extern "C"
