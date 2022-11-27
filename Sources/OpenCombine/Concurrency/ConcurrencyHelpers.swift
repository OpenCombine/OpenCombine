//
//  ConcurrencyHelpers.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.11.2022.
//

#if canImport(_Concurrency) && compiler(>=5.5)
import _Concurrency
#endif

#if (canImport(_Concurrency) && compiler(>=5.5) || compiler(>=5.5.1)) && swift(<5.7)
/// A polyfill for pre-5.7 Swift versions.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
internal func withTaskCancellationHandler<T>( // swiftlint:disable:this generic_type_name
    operation: () async throws -> T,
    onCancel handler: @Sendable () -> Void
) async rethrows -> T {
    return try await withTaskCancellationHandler(
        handler: handler,
        operation: operation
    )
}
#endif
