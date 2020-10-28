//
//  Portability.swift
//  
//
//  Created by Sergej Jaskiewicz on 28.10.2020.
//

import CoreFoundation
import Foundation

/// Use CoreFoundation on Darwin, since some pure
/// Foundation APIs are only available since macOS 10.12/iOS 10.0.
///
/// We don't have this problem on non-Darwin platforms, since swift-corelibs-foundation
/// is shipped with the toolchain, so we can always use the newest APIs.
///
/// We could use CoreFoundation everywhere, but the `RunLoop.getCFRunloop()` method
/// is marked deprecated on the swift-corelibs-foundation main branch.
///
/// Also, there are sume bugs in swift-corelibs-foundation in earlier Swift version.
internal struct Timer {

#if canImport(Darwin)
    fileprivate typealias UnderlyingTimer = CFRunLoopTimer?
#else
    fileprivate typealias UnderlyingTimer = Foundation.Timer
#endif

    fileprivate let underlyingTimer: UnderlyingTimer

    private init(underlyingTimer: UnderlyingTimer) {
        self.underlyingTimer = underlyingTimer
    }

    internal init(fire date: Date,
                  interval: TimeInterval,
                  repeats: Bool,
                  block: @escaping (Timer) -> Void) {
#if canImport(Darwin)
        underlyingTimer = CFRunLoopTimerCreateWithHandler(
            nil,
            date.timeIntervalSinceReferenceDate,
            interval,
            0,
            0,
            { block(Timer(underlyingTimer: $0)) }
        )
#else
        underlyingTimer = UnderlyingTimer(
            fire: date,
            interval: interval,
            repeats: repeats,
            block: { block(Timer(underlyingTimer: $0)) }
        )
#endif
    }

    internal init(
        timeInterval: TimeInterval,
        repeats: Bool,
        block: @escaping (Timer) -> Void
    ) {
        self.init(fire: Date(), interval: timeInterval, repeats: repeats, block: block)
    }

    internal var tolerance: TimeInterval {
        get {
#if canImport(Darwin)
            return CFRunLoopTimerGetTolerance(underlyingTimer)
#else
            return underlyingTimer.tolerance
#endif
        }
        nonmutating set {
#if canImport(Darwin)
            CFRunLoopTimerSetTolerance(underlyingTimer, newValue)
#else
            underlyingTimer.tolerance = newValue
#endif
        }
    }

    internal func invalidate() {
#if canImport(Darwin)
            CFRunLoopTimerInvalidate(underlyingTimer)
#else
            underlyingTimer.invalidate()
#endif
    }

    fileprivate func getCFRunLoopTimer() -> CFRunLoopTimer? {
#if canImport(Darwin)
        return underlyingTimer
#elseif swift(<5.2)
        // Here we use the fact that in the specified version of swift-corelibs-foundation
        // the memory layout of Foundation.Timer is as follows:
        // https://github.com/apple/swift-corelibs-foundation/blob/4cd3bf083b4705d25ac76ef8d038a06bc586265a/Foundation/Timer.swift#L18-L29

        // The first 2 words are reserved for reference counting
        let firstFieldOffset = MemoryLayout<Int>.size * 2

        return Unmanaged
            .passUnretained(underlyingTimer)
            .toOpaque()
            .load(fromByteOffset: firstFieldOffset,
                  as: CFRunLoopTimer?.self)
#else
        fatalError("unreachable")
#endif
    }
}

extension RunLoop {
    internal func add(_ timer: Timer, forMode mode: RunLoop.Mode) {
        // There is a bug in swift-corelibs-foundation prior to Swift 5.2 where
        // the timer is added to the current run loop instead of the one we're calling
        // this method on, so we fall back to CoreFoundation.
#if canImport(Darwin) || swift(<5.2)
        CFRunLoopAddTimer(getCFRunLoop(),
                          timer.getCFRunLoopTimer(),
                          mode.asCFRunLoopMode())
#else
        add(timer.underlyingTimer, forMode: mode)
#endif
    }

    internal func performBlockPortably(_ block: @escaping () -> Void) {
#if canImport(Darwin)
        CFRunLoopPerformBlock(getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue, block)
#else
        perform(block)
#endif
    }
}

extension RunLoop.Mode {
    fileprivate func asCFRunLoopMode() -> CFRunLoopMode {
#if canImport(Darwin)
        return CFRunLoopMode(rawValue as CFString)
#else
        return rawValue.withCString {
#if swift(>=5.3)
          let encoding = CFStringBuiltInEncodings.UTF8.rawValue
#else
          let encoding = CFStringEncoding(kCFStringEncodingUTF8)
#endif // swift(>=5.3)

          return CFStringCreateWithCString(
              nil,
              $0,
              encoding
          )
        }
#endif
    }
}
