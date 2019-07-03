//
//  AnyCancelableTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 15.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class AnyCancelableTests: XCTestCase {

    static let allTests = [
        ("testClosureInitialized", testClosureInitialized),
        ("testCancelableInitialized", testCancelableInitialized),
        ("testCancelTwice", testCancelTwice),
        ("testStoreInArbitraryCollection", testStoreInArbitraryCollection),
    ]

    func testClosureInitialized() {

        var fired = false

        let sut = AnyCancellable { fired = true }

        XCTAssertFalse(fired)

        sut.cancel()

        XCTAssertTrue(fired)

        fired = false

        do {
            _ = AnyCancellable { fired = true }
        }

        XCTAssertTrue(fired, "AnyCancelable should call cancel() on deinit")
    }

    func testCancelableInitialized() {

        final class CancellableObject: Cancellable {

            var fired = false

            func cancel() {
                fired = true
            }
        }

        let cancelable = CancellableObject()
        let sut = AnyCancellable(cancelable)

        XCTAssertFalse(cancelable.fired)

        sut.cancel()

        XCTAssertTrue(cancelable.fired)

        cancelable.fired = false

        do {
            _ = AnyCancellable(cancelable)
        }

        XCTAssertTrue(cancelable.fired, "AnyCancelable should call cancel() on deinit")
    }

    func testCancelTwice() {

        var counter = 0

        let cancelable = AnyCancellable { counter += 1 }

        XCTAssertEqual(counter, 0)
        cancelable.cancel()
        XCTAssertEqual(counter, 1)
        cancelable.cancel()
        XCTAssertEqual(counter, 1, "cancel() closure should only be invoked once")
    }

    func testStoreInArbitraryCollection() {

        var disposeBag = DisposeBag()

        XCTAssertEqual(disposeBag.storage, [])

        let cancellable1 = AnyCancellable({})
        cancellable1.store(in: &disposeBag)

        XCTAssertEqual(disposeBag.history, [.append])

        let cancellable2 = AnyCancellable({})
        cancellable2.store(in: &disposeBag)

        XCTAssertEqual(disposeBag.history, [.append, .append])

        XCTAssertEqual(disposeBag.storage, [cancellable1, cancellable2])
    }
}

@available(macOS 10.15, *)
private final class DisposeBag {

    enum Event {
        // Collection
        case startIndex
        case endIndex
        case makeIterator
        case subscriptPosition
        case subscriptBounds
        case indices
        case isEmpty
        case count
        case indexOffsetBy
        case indexOffsetByLimitedBy
        case distance
        case indexAfter
        case formIndexAfter

        // RangeReplaceableCollection
        case replaceSubrange
        case reserveCapacity
        case append
        case appendSequence
        case insertAt
        case insertSequenceAt
    }

    private(set) var history: [Event]

    private(set) var storage: [AnyCancellable]

    init() {
        history = []
        storage = []
    }
}

@available(macOS 10.15, *)
extension DisposeBag: Collection {

    var startIndex: Int {
        history.append(.startIndex)
        return storage.startIndex
    }

    var endIndex: Int {
        history.append(.endIndex)
        return storage.endIndex
    }

    func makeIterator() -> IndexingIterator<[AnyCancellable]> {
        return storage.makeIterator()
    }

    subscript(position: Int) -> AnyCancellable {
        history.append(.subscriptPosition)
        return storage[position]
    }

    subscript(bounds: Range<Int>) -> Slice<DisposeBag> {
        history.append(.subscriptBounds)
        return Slice(base: self, bounds: bounds)
    }

    var indices: Range<Int> {
        history.append(.indices)
        return storage.indices
    }

    var isEmpty: Bool {
        history.append(.isEmpty)
        return storage.isEmpty
    }

    var count: Int {
        history.append(.count)
        return storage.count
    }

    func index(_ i: Int, offsetBy distance: Int) -> Int {
        history.append(.indexOffsetBy)
        return storage.index(i, offsetBy: distance)
    }

    func index(_ i: Int, offsetBy distance: Int, limitedBy limit: Int) -> Int? {
        history.append(.indexOffsetByLimitedBy)
        return storage.index(i, offsetBy: distance, limitedBy: limit)
    }

    func distance(from start: Int, to end: Int) -> Int {
        history.append(.distance)
        return storage.distance(from: start, to: end)
    }

    func index(after i: Int) -> Int {
        history.append(.indexAfter)
        return storage.index(after: i)
    }

    func formIndex(after i: inout Int) {
        history.append(.formIndexAfter)
        storage.formIndex(after: &i)
    }
}

@available(macOS 10.15, *)
extension DisposeBag: RangeReplaceableCollection {

    func replaceSubrange<NewElements: Collection, RangeExpr: RangeExpression>(
        _ subrange: RangeExpr,
        with newElements: NewElements
    ) where NewElements.Element == AnyCancellable, RangeExpr.Bound == Int {
        history.append(.replaceSubrange)
        storage.replaceSubrange(subrange, with: newElements)
    }

    func reserveCapacity(_ n: Int) {
        history.append(.reserveCapacity)
        storage.reserveCapacity(n)
    }

    func append(_ newElement: AnyCancellable) {
        history.append(.append)
        storage.append(newElement)
    }

    func append<NewElements: Sequence>(contentsOf newElements: NewElements)
        where NewElements.Element == AnyCancellable
    {
        history.append(.appendSequence)
        storage.append(contentsOf: newElements)
    }

    func insert(_ newElement: AnyCancellable, at i: Int) {
        history.append(.insertAt)
        storage.insert(newElement, at: i)
    }

    func insert<NewElements: Collection>(contentsOf newElements: NewElements, at i: Int)
        where NewElements.Element == AnyCancellable
    {
        history.append(.insertSequenceAt)
        storage.insert(contentsOf: newElements, at: i)
    }
}
