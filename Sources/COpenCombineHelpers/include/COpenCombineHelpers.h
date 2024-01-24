//
//  COpenCombineHelpers.h
//  
//
//  Created by Sergej Jaskiewicz on 23/09/2019.
//

#ifndef COPENCOMBINEHELPERS_H
#define COPENCOMBINEHELPERS_H

#include <stdint.h>
#include <stdbool.h>
#include "Compiler.h"
#include "lock_private.h"

#if __has_attribute(swift_name)
# define OPENCOMBINE_SWIFT_NAME(_name) __attribute__((swift_name(#_name)))
#else
# define OPENCOMBINE_SWIFT_NAME(_name)
#endif

#ifdef __cplusplus
extern "C" {
#endif

#pragma mark - CombineIdentifier

uint64_t opencombine_next_combine_identifier(void)
    OPENCOMBINE_SWIFT_NAME(__nextCombineIdentifier());

#pragma mark - OpenCombineUnfairLock

/// A wrapper around an opaque pointer for type safety in Swift.
typedef struct OpenCombineUnfairLock {
    void* _Nonnull opaque;
} OPENCOMBINE_SWIFT_NAME(__UnfairLock) OpenCombineUnfairLock;

/// Allocates a lock object. The allocated object must be destroyed by calling
/// the destroy() method.
OpenCombineUnfairLock opencombine_unfair_lock_alloc(void)
    OPENCOMBINE_SWIFT_NAME(__UnfairLock.allocate());

void opencombine_unfair_lock_lock(OpenCombineUnfairLock)
    OPENCOMBINE_SWIFT_NAME(__UnfairLock.lock(self:));

void opencombine_unfair_lock_unlock(OpenCombineUnfairLock)
    OPENCOMBINE_SWIFT_NAME(__UnfairLock.unlock(self:));

void opencombine_unfair_lock_assert_owner(OpenCombineUnfairLock mutex)
    OPENCOMBINE_SWIFT_NAME(__UnfairLock.assertOwner(self:));

void opencombine_unfair_lock_dealloc(OpenCombineUnfairLock lock)
    OPENCOMBINE_SWIFT_NAME(__UnfairLock.deallocate(self:));

#pragma mark - OpenCombineUnfairRecursiveLock

/// A wrapper around an opaque pointer for type safety in Swift.
typedef struct OpenCombineUnfairRecursiveLock {
    void* _Nonnull opaque;
} OPENCOMBINE_SWIFT_NAME(__UnfairRecursiveLock) OpenCombineUnfairRecursiveLock;

OpenCombineUnfairRecursiveLock opencombine_unfair_recursive_lock_alloc(void)
    OPENCOMBINE_SWIFT_NAME(__UnfairRecursiveLock.allocate());

void opencombine_unfair_recursive_lock_lock(OpenCombineUnfairRecursiveLock)
    OPENCOMBINE_SWIFT_NAME(__UnfairRecursiveLock.lock(self:));

void opencombine_unfair_recursive_lock_unlock(OpenCombineUnfairRecursiveLock)
    OPENCOMBINE_SWIFT_NAME(__UnfairRecursiveLock.unlock(self:));

void opencombine_unfair_recursive_lock_dealloc(OpenCombineUnfairRecursiveLock lock)
    OPENCOMBINE_SWIFT_NAME(__UnfairRecursiveLock.deallocate(self:));

#pragma mark - Breakpoint

void opencombine_stop_in_debugger(void) OPENCOMBINE_SWIFT_NAME(__stopInDebugger());

#pragma mark - COMPILER_SUPPORTS

bool opencombine_sanitize_address_enabled(void) OPENCOMBINE_SWIFT_NAME(__sanitizeAddressEnabled());

bool opencombine_sanitize_thread_enabled(void) OPENCOMBINE_SWIFT_NAME(__sanitizeThreadEnabled());

bool opencombine_sanitize_coverage_enabled(void) OPENCOMBINE_SWIFT_NAME(__sanitizeCoverageEnabled());

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* COPENCOMBINEHELPERS_H */
