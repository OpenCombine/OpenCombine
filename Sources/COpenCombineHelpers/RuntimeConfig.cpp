//
//  RuntimeConfig.cpp
//  
//
//  Created by Sergej Jaskiewicz on 31.10.2019.
//

// The content of this file is based on
// https://github.com/apple/swift/blob/master/stdlib/public/runtime/BackDeployment.cpp
// and must be updated accordingly.

#if defined(__APPLE__) && defined(__MACH__)
#include "RuntimeConfig.h"

/// Returns true if the current OS version, at runtime, is a back-deployment
/// version.
static bool isBackDeploying() {
    if (__builtin_available(macOS 10.14.4, watchOS 5.2.0, iOS 12.2.0, tvOS 12.2.0, *)) {
        return false;
    } else {
        // We're in a pre-ABI-stable world
        return true;
    }
}

static unsigned long long computeIsSwiftMask() {
    return isBackDeploying() ? 1ULL : 2ULL;
}

namespace opencombine {
unsigned long long classIsSwiftMask = computeIsSwiftMask();
}

#endif
