//===--- Config.h - Swift Language Platform Configuration -------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Definitions of common interest in Swift.
//
//===----------------------------------------------------------------------===//

// MODIFICATION NOTE:
// This file has been modified for the OpenCombine open source project.
// Some macros have been renamed or removed.

#ifndef OPENCOMBINE_SWIFT_RUNTIME_CONFIG_H
#define OPENCOMBINE_SWIFT_RUNTIME_CONFIG_H

/// \macro SWIFT_RUNTIME_GNUC_PREREQ
/// Extend the default __GNUC_PREREQ even if glibc's features.h isn't
/// available.
#ifndef SWIFT_RUNTIME_GNUC_PREREQ
# if defined(__GNUC__) && defined(__GNUC_MINOR__) && defined(__GNUC_PATCHLEVEL__)
#  define SWIFT_RUNTIME_GNUC_PREREQ(maj, min, patch) \
    ((__GNUC__ << 20) + (__GNUC_MINOR__ << 10) + __GNUC_PATCHLEVEL__ >= \
     ((maj) << 20) + ((min) << 10) + (patch))
# elif defined(__GNUC__) && defined(__GNUC_MINOR__)
#  define SWIFT_RUNTIME_GNUC_PREREQ(maj, min, patch) \
    ((__GNUC__ << 20) + (__GNUC_MINOR__ << 10) >= ((maj) << 20) + ((min) << 10))
# else
#  define SWIFT_RUNTIME_GNUC_PREREQ(maj, min, patch) 0
# endif
#endif

#ifdef __GNUC__
#define SWIFT_RUNTIME_ATTRIBUTE_NORETURN __attribute__((noreturn))
#elif defined(_MSC_VER)
#define SWIFT_RUNTIME_ATTRIBUTE_NORETURN __declspec(noreturn)
#else
#define SWIFT_RUNTIME_ATTRIBUTE_NORETURN
#endif

/// SWIFT_RUNTIME_BUILTIN_TRAP - On compilers which support it, expands to an expression
/// which causes the program to exit abnormally.
#if __has_builtin(__builtin_trap) || SWIFT_RUNTIME_GNUC_PREREQ(4, 3, 0)
# define SWIFT_RUNTIME_BUILTIN_TRAP __builtin_trap()
#elif defined(_MSC_VER)
// The __debugbreak intrinsic is supported by MSVC, does not require forward
// declarations involving platform-specific typedefs (unlike RaiseException),
// results in a call to vectored exception handlers, and encodes to a short
// instruction that still causes the trapping behavior we want.
# define SWIFT_RUNTIME_BUILTIN_TRAP __debugbreak()
#else
# define SWIFT_RUNTIME_BUILTIN_TRAP *(volatile int*)0x11 = 0
#endif

/// Does the current Swift platform support "unbridged" interoperation
/// with Objective-C?  If so, the implementations of various types must
/// implicitly handle Objective-C pointers.
///
/// Apple platforms support this by default.
#ifndef SWIFT_OBJC_INTEROP
#ifdef __APPLE__
#define SWIFT_OBJC_INTEROP 1
#else
#define SWIFT_OBJC_INTEROP 0
#endif
#endif

/// Does the current Swift platform allow information other than the
/// class pointer to be stored in the isa field?  If so, when deriving
/// the class pointer of an object, we must apply a
/// dynamically-determined mask to the value loaded from the first
/// field of the object.
///
/// According to the Objective-C ABI, this is true only for 64-bit
/// platforms.
#ifndef SWIFT_HAS_ISA_MASKING
#if SWIFT_OBJC_INTEROP && __POINTER_WIDTH__ == 64
#define SWIFT_HAS_ISA_MASKING 1
#else
#define SWIFT_HAS_ISA_MASKING 0
#endif
#endif

/// Does the current Swift platform have ISA pointers which should be opaque
/// to anyone outside the Swift runtime?  Similarly to the ISA_MASKING case
/// above, information other than the class pointer could be contained in the
/// ISA.
#ifndef SWIFT_HAS_OPAQUE_ISAS
#if defined(__arm__) && __ARM_ARCH_7K__ >= 2
#define SWIFT_HAS_OPAQUE_ISAS 1
#else
#define SWIFT_HAS_OPAQUE_ISAS 0
#endif
#endif

#if SWIFT_HAS_OPAQUE_ISAS && SWIFT_HAS_ISA_MASKING
#error Masking ISAs are incompatible with opaque ISAs
#endif

/// Which bits in the class metadata are used to distinguish Swift classes
/// from ObjC classes?
#ifndef SWIFT_CLASS_IS_SWIFT_MASK

# if !defined(__APPLE__)
// Non-Apple platforms always use 1.
#  define SWIFT_CLASS_IS_SWIFT_MASK 1ULL
# else
// Apple platforms with Swift in the OS (a.k.a. post-ABI-stability) use 2.
namespace opencombine { extern unsigned long long classIsSwiftMask; }
# define OPENCOMBINE_SWIFT_CLASS_IS_SWIFT_MASK classIsSwiftMask
# endif
#endif

// Define mappings for calling conventions.

#if __has_attribute(swiftcall)
# define OPENCOMBINE_SWIFT_CALLING_CONVENTION __attribute__((swiftcall))
# define OPENCOMBINE_SWIFT_CONTEXT __attribute__((swift_context))
# define OPENCOMBINE_SWIFT_ERROR_RESULT __attribute__((swift_error_result))
# define OPENCOMBINE_SWIFT_INDIRECT_RESULT __attribute__((swift_indirect_result))
#else
# define OPENCOMBINE_SWIFT_CALLING_CONVENTION
# define OPENCOMBINE_SWIFT_CONTEXT
# define OPENCOMBINE_SWIFT_ERROR_RESULT
# define OPENCOMBINE_SWIFT_INDIRECT_RESULT
#endif

#endif // OPENCOMBINE_SWIFT_RUNTIME_CONFIG_H
