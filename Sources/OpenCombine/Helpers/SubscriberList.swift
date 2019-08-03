//
//  SubscriberList.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.08.2019.
//

internal typealias Ticket = Int

internal struct SubscriberList {

    // Apple's Combine uses Unmanaged, apparently, to avoid
    // reference counting overhead
    private var items: [Unmanaged<AnyObject>]

    /// This array is used to locate a subscription in the `items` array.
    ///
    /// `tickets` array is always sorted.
    private var tickets: [Ticket]

    private var nextTicket: Ticket

    internal init() {
        items = []
        tickets = []
        nextTicket = 0
    }

    /// `element` should be passed retained.
    @inline(__always)
    internal mutating func insert(_ element: Unmanaged<AnyObject>) -> Ticket {
        defer {
            nextTicket += 1
        }

        items.append(element)
        tickets.append(nextTicket)

        assert(items.count == tickets.count)

        return nextTicket
    }

    @inline(__always)
    internal mutating func remove(for ticket: Ticket) {
        guard let index = tickets.firstIndex(of: ticket) else { return }
        tickets.remove(at: index)
        items[index].release()
        items.remove(at: index)

        assert(items.count == tickets.count)
    }

    @inline(__always)
    internal func retainAll() {
        items.forEach { _ = $0.retain() }
    }

    @inline(__always)
    internal mutating func clear() {
        items = []
        tickets = []
    }
}

extension SubscriberList: Sequence {

    func makeIterator() -> IndexingIterator<[Unmanaged<AnyObject>]> {
        return items.makeIterator()
    }

    var underestimatedCount: Int { return items.underestimatedCount }

    func withContiguousStorageIfAvailable<Result>(
        _ body: (UnsafeBufferPointer<Unmanaged<AnyObject>>) throws -> Result
    ) rethrows -> Result? {
        return try items.withContiguousStorageIfAvailable(body)
    }
}
