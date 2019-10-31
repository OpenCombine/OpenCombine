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
#include <cstdint>

/// Returns true if the current OS version, at runtime, is a back-deployment
/// version.
static bool _opencombine_swift_isBackDeploying();

namespace opencombine {
namespace swift {
extern "C" {

// This struct is layout-compatible with NSOperatingSystemVersion.
struct OpenCombineNSOperatingSystemVersion {
    intptr_t majorVersion;
    intptr_t minorVersion;
    intptr_t patchVersion;
};

// This function is defined in the Swift stdlib.
OpenCombineNSOperatingSystemVersion
_swift_stdlib_operatingSystemVersion() __attribute__((const));

} // extern "C"
} // end namespace swift
} // end namespace opencombine

static unsigned long long computeIsSwiftMask() {
    return _opencombine_swift_isBackDeploying() ? 1ULL : 2ULL;
}

unsigned long long _opencombine_swift_classIsSwiftMask = computeIsSwiftMask();

static opencombine::swift::OpenCombineNSOperatingSystemVersion swiftInOSVersion = {
#if __MAC_OS_X_VERSION_MIN_REQUIRED
  10, 14, 4
// WatchOS also pretends to be iOS, so check it first.
#elif __WATCH_OS_VERSION_MIN_REQUIRED
   5,  2, 0
#elif __IPHONE_OS_VERSION_MIN_REQUIRED || __TV_OS_VERSION_MIN_REQUIRED
  12,  2, 0
#else
  9999, 0, 0
#endif
};

static bool versionLessThan(opencombine::swift::OpenCombineNSOperatingSystemVersion lhs,
                            opencombine::swift::OpenCombineNSOperatingSystemVersion rhs) {
  if (lhs.majorVersion < rhs.majorVersion) return true;
  if (lhs.majorVersion > rhs.majorVersion) return false;

  if (lhs.minorVersion < rhs.minorVersion) return true;
  if (lhs.minorVersion > rhs.minorVersion) return false;

  if (lhs.patchVersion < rhs.patchVersion) return true;

  return false;
}

static bool _opencombine_swift_isBackDeploying() {
  auto version = opencombine::swift::_swift_stdlib_operatingSystemVersion();
  return versionLessThan(version, swiftInOSVersion);
}

#endif
