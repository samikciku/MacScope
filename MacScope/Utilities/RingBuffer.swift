struct RingBuffer<Element>: RandomAccessCollection, Sendable where Element: Sendable {
    typealias Index = Int

    private var storage: [Element?]
    private var writeIndex = 0
    private(set) var count = 0

    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be greater than zero")
        self.capacity = capacity
        storage = Array(repeating: nil, count: capacity)
    }

    var startIndex: Int { 0 }
    var endIndex: Int { count }

    subscript(position: Int) -> Element {
        precondition(indices.contains(position), "Index out of bounds")
        let oldest = count == capacity ? writeIndex : 0
        return storage[(oldest + position) % capacity]!
    }

    mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = Swift.min(count + 1, capacity)
    }
}
