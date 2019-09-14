//
//  PublishedTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 08/09/2019.
//

import XCTest

#if swift(>=5.1)

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine

@available(macOS 10.15, iOS 13.0, *)
private typealias Published = Combine.Published
#else
import OpenCombine

private typealias Published = OpenCombine.Published
#endif

@available(macOS 10.15, iOS 13.0, *)
final class PublishedTests: XCTestCase {

    func testA() {
        let oop = ObservableObjectPublisher()
        dump(oop)
    }
}

@available(macOS 10.15, iOS 13.0, *)
private final class TestObject {
    @Published var state: Int

    init() {
        state = 0
    }
}

#endif
