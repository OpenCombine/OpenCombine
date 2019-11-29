//
//  RuntimeConfig.h
//  
//
//  Created by Sergej Jaskiewicz on 31.10.2019.
//

#ifndef OPENCOMBINE_RUNTIME_CONFIG_H
#define OPENCOMBINE_RUNTIME_CONFIG_H

#define OPENCOMBINE_NO_CONSTRUCTORS(type_name)                                           \
    type_name(const type_name&) = delete;                                                \
    type_name& operator=(const type_name&) = delete;                                     \
    type_name(type_name&&) = delete;                                                     \
    type_name& operator=(type_name&&) = delete;

#if __has_attribute(swiftcall)
# define OPENCOMBINE_SWIFT_CALLING_CONVENTION __attribute__((swiftcall))
#else
# define OPENCOMBINE_SWIFT_CALLING_CONVENTION
#endif

#if !defined(__APPLE__)

// Non-Apple platforms always use 1.
# define OPENCOMBINE_SWIFT_CLASS_IS_SWIFT_MASK 1ULL

#else // defined(__APPLE__)

// Apple platforms with Swift in OS (a.k.a. post-ABI-stability) use 2.
namespace opencombine {
extern unsigned long long classIsSwiftMask;
}
# define OPENCOMBINE_SWIFT_CLASS_IS_SWIFT_MASK classIsSwiftMask

#endif // !defined(__APPLE__)

#endif /* OPENCOMBINE_RUNTIME_CONFIG_H */
