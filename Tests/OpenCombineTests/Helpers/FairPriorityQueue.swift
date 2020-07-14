//
//  FairPriorityQueue.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.12.2019.
//

/// A priority queue based on binary min-heap.
/// If two elements with the same priority are added, the element that was added
/// earlier has will have "better" priority (i. e. it will be also extracted earlier).
struct FairPriorityQueue<Priority: Comparable, Element> {

    private var storage: [((Priority, UInt), Element)] = []
    private var next: UInt = 0

    init() {}

    mutating func insert(_ element: Element, priority: Priority) {
        storage.append(((priority, next), element))
        next += 1
        var newElementIndex = storage.endIndex - 1
        while let parent = self.parent(of: newElementIndex),
              storage[parent].0 > storage[newElementIndex].0 {
            storage.swapAt(newElementIndex, parent)
            newElementIndex = parent
        }
    }

    func min() -> (Priority, Element)? {
        return storage.first.map { ($0.0.0, $0.1) }
    }

    @discardableResult
    mutating func extractMin() -> (Priority, Element)? {
        guard let max = storage.first else { return nil }
        storage[0] = storage[storage.endIndex - 1]
        storage.removeLast()
        minHeapify(0)
        return (max.0.0, max.1)
    }

    var count: Int {
        return storage.count
    }

    var isEmpty: Bool {
        return storage.isEmpty
    }

    private func leftChild(of index: Int) -> Int? {
        assert(index >= 0)
        let childIndex = 2 * index + 1
        return childIndex < storage.endIndex ? childIndex : nil
    }

    private func rightChild(of index: Int) -> Int? {
        assert(index >= 0)
        let childIndex = 2 * index + 2
        return childIndex < storage.endIndex ? childIndex : nil
    }

    private func parent(of index: Int) -> Int? {
        assert(index >= 0)
        if index == 0 { return nil }
        return (index - 1) / 2
    }

    private mutating func minHeapify(_ root: Int) {
        var root = root
        var largest = root
        while true {
            assert(largest == root)
            if let left = leftChild(of: root), storage[root].0 > storage[left].0 {
                largest = left
            }
            if let right = rightChild(of: root), storage[largest].0 > storage[right].0 {
                largest = right
            }
            if largest == root {
                break
            }
            storage.swapAt(root, largest)
            root = largest
        }
    }
}

extension FairPriorityQueue: Sequence {
    struct Iterator: IteratorProtocol {
        private var queue: FairPriorityQueue

        fileprivate init(_ queue: FairPriorityQueue) {
            self.queue = queue
        }

        mutating func next() -> (Priority, Element)? {
            return queue.extractMin()
        }
    }

    func makeIterator() -> Iterator {
        return Iterator(self)
    }
}
