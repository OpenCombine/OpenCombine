//
//  ExecuteOnBackgroundThread.swift
//  
//
//  Created by Sergej Jaskiewicz on 04.02.2020.
//

#if !os(WASI)

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import WinSDK
#else
#error("How to do threads on this platform?")
#endif

// We could use Foundation's Thread, but it doesn't work on Linux for some
// reason.

func executeOnBackgroundThread<ResultType>(
    _ body: () -> ResultType
) -> ResultType {
    return withoutActuallyEscaping(body) { body in
        typealias ThreadRoutine = () -> UnsafeMutableRawPointer

#if canImport(Darwin)
        typealias ThreadHandle = UnsafeMutablePointer<pthread_t?>
#elseif canImport(Glibc)
        typealias ThreadHandle = UnsafeMutablePointer<pthread_t>
#elseif os(Windows)
        typealias ThreadHandle = HANDLE?
#endif

        let typeErasedBody: ThreadRoutine = {
            let resultPtr = UnsafeMutablePointer<ResultType>.allocate(capacity: 1)
            resultPtr.initialize(to: body())
            return UnsafeMutableRawPointer(resultPtr)
        }

        var _backgroundThread: ThreadHandle

#if os(Windows)
        typealias ResultPtr = UnsafeMutablePointer<UnsafeMutableRawPointer>
        typealias Context = (ThreadRoutine, ResultPtr)
        var resultPtr: ResultPtr = .allocate(capacity: 1)
        defer { resultPtr.deallocate() }
        _backgroundThread = nil
        var context: Context = (typeErasedBody, resultPtr)
#else
        _backgroundThread = .allocate(capacity: 1)
        defer { _backgroundThread.deallocate() }
        var context = typeErasedBody
#endif

        return withUnsafeMutablePointer(to: &context) { context in
#if os(Windows)
            _backgroundThread = CreateThread(
                nil, // default security attributes
                0, // use default stack size
                { context in
                    let (typeErasedBody, resultPtr) = context!
                        .assumingMemoryBound(to: Context.self)
                        .pointee

                    resultPtr.initialize(to: typeErasedBody())
                    return 0
                },
                context,
                0, // use default creation flags
                nil // don't return thread identifier
            )
            precondition(_backgroundThread != nil, "Could not create a thread")

            WaitForSingleObject(_backgroundThread!, INFINITE)

            defer { resultPtr.pointee.deallocate() }

            return resultPtr.pointee.assumingMemoryBound(to: ResultType.self).move()
#else
            var status = pthread_create(
                _backgroundThread,
                nil,
                { context in
#if canImport(Darwin)
                    let context = context
#else
                    let context = context!
#endif
                    return context
                        .assumingMemoryBound(to: ThreadRoutine.self)
                        .pointee()
                },
                context
            )

            precondition(status == 0, "Could not create a thread")

#if canImport(Darwin)
            guard let backgroundThread = _backgroundThread.pointee else {
                preconditionFailure("Could not join thread")
            }
#else
            let backgroundThread = _backgroundThread.pointee
#endif

            var _resultPtr: UnsafeMutableRawPointer?
            status = pthread_join(backgroundThread, &_resultPtr)

            guard status == 0, let resultPtr = _resultPtr else {
                preconditionFailure("Could not join thread")
            }

            defer { resultPtr.deallocate() }

            return resultPtr.assumingMemoryBound(to: ResultType.self).move()
#endif
        }
    }
}

#endif // !os(WASI)
