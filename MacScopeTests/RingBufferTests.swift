import Testing
@testable import MacScope

struct RingBufferTests {
    @Test func preservesInsertionOrderBeforeCapacity() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)

        #expect(Array(buffer) == [1, 2])
    }

    @Test func wrapsAndKeepsNewestValuesInChronologicalOrder() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for value in 1...5 {
            buffer.append(value)
        }

        #expect(Array(buffer) == [3, 4, 5])
    }
}
