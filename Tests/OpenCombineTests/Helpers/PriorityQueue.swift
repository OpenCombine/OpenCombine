//
//  PriorityQueue.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.12.2019.
//

/// A priproty queue based on binary max-heap.
struct PriorityQueue<Element> {
    private var storage: [Element]
    private let areInIncreasingOrder: (Element, Element) -> Bool

    init(_ areInIncreasingOrder: @escaping (Element, Element) -> Bool) {
        self.storage = []
        self.areInIncreasingOrder = areInIncreasingOrder
    }

    mutating func insert(_ element: Element) {
        storage.append(element)
        var newElementIndex = storage.endIndex - 1
        while let parent = self.parent(of: newElementIndex),
              areInIncreasingOrder(storage[parent], storage[newElementIndex]) {
            storage.swapAt(newElementIndex, parent)
            newElementIndex = parent
        }
    }

    func max() -> Element? {
        return storage.first
    }

    @discardableResult
    mutating func extractMax() -> Element? {
        guard let max = storage.first else { return nil }
        storage[0] = storage[storage.endIndex - 1]
        storage.removeLast()
        maxHeapify(0)
        return max
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

    private mutating func maxHeapify(_ root: Int) {
        var root = root
        var largest = root
        while true {
            assert(largest == root)
            if let left = leftChild(of: root),
               areInIncreasingOrder(storage[root], storage[left]) {
                largest = left
            }
            if let right = rightChild(of: root),
               areInIncreasingOrder(storage[largest], storage[right]) {
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

extension PriorityQueue where Element: Comparable {
    init() {
        self.init(<)
    }
}

extension PriorityQueue: Sequence {
    struct Iterator: IteratorProtocol {
        private var queue: PriorityQueue

        fileprivate init(_ queue: PriorityQueue) {
            self.queue = queue
        }

        mutating func next() -> Element? {
            return queue.extractMax()
        }
    }

    func makeIterator() -> Iterator {
        return Iterator(self)
    }
}
