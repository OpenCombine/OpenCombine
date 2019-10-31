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

// Non-Apple platforms always use 1.
#if !defined(__APPLE__)
#define OPENCOMBINE_SWIFT_CLASS_IS_SWIFT_MASK 1ULL

// Other builds (such as local builds on developers' computers)
// dynamically choose the bit at runtime based on the current OS
// version.
#else // defined(__APPLE__)
extern unsigned long long _opencombine_swift_classIsSwiftMask;
#define OPENCOMBINE_SWIFT_CLASS_IS_SWIFT_MASK _opencombine_swift_classIsSwiftMask

#endif // !defined(__APPLE__)

#endif /* OPENCOMBINE_RUNTIME_CONFIG_H */
