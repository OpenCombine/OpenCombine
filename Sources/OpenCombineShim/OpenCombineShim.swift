#if canImport(Combine)
@_exported import Combine
#else
@_exported import OpenCombine
#if canImport(OpenCombineDispatch)
@_exported import OpenCombineDispatch
#endif
#if canImport(OpenCombineFoundation)
@_exported import OpenCombineFoundation
#endif
#endif
