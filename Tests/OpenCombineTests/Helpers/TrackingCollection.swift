//
//  TrackingCollection.swift
//  
//
//  Created by Sergej Jaskiewicz on 04.07.2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
typealias DisposeBag = TrackingCollection<AnyCancellable>

final class TrackingCollection<Element> {

    enum Event: String, CustomStringConvertible {
        // Sequence
        case makeIterator
        case underestimatedCount

        // Collection
        case startIndex
        case endIndex
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
        case emptyInit
        case replaceSubrange
        case reserveCapacity
        case initRepeating
        case initFromSequence
        case append
        case appendSequence
        case insertAt
        case insertSequenceAt
        case removeAt
        case removeSubrange
        case removeFirst
        case removeFirstK
        case removeAll
        case removeAllWhere

        var description: String { return rawValue }
    }

    private(set) var history: [Event]

    private(set) var storage: [Element]

    private init(history: [Event], storage: [Element]) {
        self.history = history
        self.storage = storage
    }
}

extension TrackingCollection: Sequence {
    func makeIterator() -> IndexingIterator<[Element]> {
        history.append(.makeIterator)
        return storage.makeIterator()
    }

    var underestimatedCount: Int {
        history.append(.underestimatedCount)
        return storage.underestimatedCount
    }
}

extension TrackingCollection: Collection {

    var startIndex: Int {
        history.append(.startIndex)
        return storage.startIndex
    }

    var endIndex: Int {
        history.append(.endIndex)
        return storage.endIndex
    }

    subscript(position: Int) -> Element {
        history.append(.subscriptPosition)
        return storage[position]
    }

    subscript(bounds: Range<Int>) -> Slice<TrackingCollection> {
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

extension TrackingCollection: RangeReplaceableCollection {

    convenience init() {
        self.init(history: [.emptyInit], storage: [])
    }

    func replaceSubrange<NewElements: Collection, RangeExpr: RangeExpression>(
        _ subrange: RangeExpr,
        with newElements: NewElements
    ) where NewElements.Element == Element, RangeExpr.Bound == Int {
        history.append(.replaceSubrange)
        storage.replaceSubrange(subrange, with: newElements)
    }

    func reserveCapacity(_ n: Int) {
        history.append(.reserveCapacity)
        storage.reserveCapacity(n)
    }

    convenience init(repeating repeatedValue: Element, count: Int) {
        self.init(history: [.initRepeating],
                  storage: Array(repeating: repeatedValue, count: count))
    }

    convenience init<OtherSequence: Sequence>(_ elements: OtherSequence)
        where OtherSequence.Element == Element
    {
        self.init(history: [.initFromSequence], storage: Array(elements))
    }

    func append(_ newElement: Element) {
        history.append(.append)
        storage.append(newElement)
    }

    func append<NewElements: Sequence>(contentsOf newElements: NewElements)
        where NewElements.Element == Element
    {
        history.append(.appendSequence)
        storage.append(contentsOf: newElements)
    }

    func insert(_ newElement: Element, at i: Int) {
        history.append(.insertAt)
        storage.insert(newElement, at: i)
    }

    func insert<NewElements: Collection>(contentsOf newElements: NewElements, at i: Int)
        where NewElements.Element == Element
    {
        history.append(.insertSequenceAt)
        storage.insert(contentsOf: newElements, at: i)
    }

    func remove(at position: Int) -> Element {
        history.append(.removeAt)
        return storage.remove(at: position)
    }

    func removeSubrange(_ bounds: Range<Int>) {
        history.append(.removeSubrange)
        storage.removeSubrange(bounds)
    }

    func removeFirst() -> Element {
        history.append(.removeFirst)
        return storage.removeFirst()
    }

    func removeFirst(_ k: Int) {
        history.append(.removeFirstK)
        storage.removeFirst(k)
    }

    func removeAll(keepingCapacity keepCapacity: Bool) {
        history.append(.removeAll)
        storage.removeAll(keepingCapacity: keepCapacity)
    }

    func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        history.append(.removeAllWhere)
        try storage.removeAll(where: shouldBeRemoved)
    }
}

final class TrackingRangeExpression<RangeExpression: Swift.RangeExpression>
    : Swift.RangeExpression
    where RangeExpression.Bound == Int
{
    enum Event: Equatable {
        case contains(Int)
        case relativeTo(Range<Int>?)
    }

    typealias Bound = Int

    private let underlying: RangeExpression
    private(set) var history: [Event] = []

    init(_ underlying: RangeExpression) {
        self.underlying = underlying
    }

    func relative<Elements: Collection>(
        to collection: Elements
    ) -> Range<Int> where Elements.Index == Int {
        history.append(.relativeTo(collection as? Range<Int>))
        return underlying.relative(to: collection)
    }

    func contains(_ element: Int) -> Bool {
        history.append(.contains(element))
        return underlying.contains(element)
    }
}
