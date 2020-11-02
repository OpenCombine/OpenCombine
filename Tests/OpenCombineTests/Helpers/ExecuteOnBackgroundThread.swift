//
//  ExecuteOnBackgroundThread.swift
//  
//
//  Created by Sergej Jaskiewicz on 04.02.2020.
//

#if !WASI

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("How to do threads on this platform?")
#endif

#if canImport(Darwin)
private typealias ThreadPtr = UnsafeMutablePointer<pthread_t?>
#else
private typealias ThreadPtr = UnsafeMutablePointer<pthread_t>
#endif

func executeOnBackgroundThread<ResultType>(
    _ body: () -> ResultType
) -> ResultType {
    return withoutActuallyEscaping(body) { body in

        // We need this because @convention(c) closures can't capture generic params.
        var typeErasedBody: () -> UnsafeMutableRawPointer = {
            let resultPtr = UnsafeMutablePointer<ResultType>.allocate(capacity: 1)
            resultPtr.initialize(to: body())
            return UnsafeMutableRawPointer(resultPtr)
        }

        return withUnsafeMutablePointer(to: &typeErasedBody) { typeErasedBody in
            let _backgroundThread = ThreadPtr.allocate(capacity: 1)

            defer { _backgroundThread.deallocate() }

            var status: Int32 = 0

            // We could use Foundation's Thread, but it doesn't work on Linux for some
            // reason.
            status = pthread_create(
                _backgroundThread,
                nil,
                { context in
#if canImport(Darwin)
                    let context = context
#else
                    let context = context!
#endif
                    return context
                        .assumingMemoryBound(to: (() -> UnsafeMutableRawPointer).self)
                        .pointee()
                },
                typeErasedBody
            )

            guard status == 0 else {
                preconditionFailure("Could not create a background thread")
            }

#if canImport(Darwin)
            guard let backgroundThread = _backgroundThread.pointee else {
                preconditionFailure("Could not create a background thread")
            }
#else
            let backgroundThread = _backgroundThread.pointee
#endif

            var _resultPtr: UnsafeMutableRawPointer?
            status = pthread_join(backgroundThread, &_resultPtr)

            guard status == 0, let resultPtr = _resultPtr else {
                preconditionFailure("Could not join threads")
            }

            defer { resultPtr.deallocate() }

            return resultPtr.assumingMemoryBound(to: ResultType.self).move()
        }
    }
}

#endif // !WASI
