import Testing
@testable import MacScope

struct MemoryCalculationsTests {
    @Test func convertsPageCountsAndDerivesAvailableMemory() {
        let result = MemoryCalculations.bytes(
            totalBytes: 1_000,
            pageSize: 10,
            counts: MemoryPageCounts(
                free: 10,
                active: 30,
                inactive: 20,
                wired: 15,
                compressed: 5,
                purgeable: 5
            )
        )

        #expect(result.free == 100)
        #expect(result.active == 300)
        #expect(result.inactive == 200)
        #expect(result.wired == 150)
        #expect(result.compressed == 50)
        #expect(result.purgeable == 50)
        #expect(result.available == 350)
        #expect(result.used == 650)
    }

    @Test func capsAvailableAtPhysicalMemory() {
        let result = MemoryCalculations.bytes(
            totalBytes: 100,
            pageSize: 10,
            counts: MemoryPageCounts(
                free: 20,
                active: 0,
                inactive: 20,
                wired: 0,
                compressed: 0,
                purgeable: 20
            )
        )

        #expect(result.available == 100)
        #expect(result.used == 0)
    }

    @Test func calculatesPagingTotalsAndRatesFromConsecutiveSnapshots() {
        let previous = MemoryPagingSnapshot(timestamp: 10, pageIns: 100, pageOuts: 40)
        let current = MemoryPagingSnapshot(timestamp: 12, pageIns: 110, pageOuts: 44)

        let result = MemoryCalculations.paging(
            current: current,
            previous: previous,
            pageSize: 4_096
        )

        #expect(result.pageInsBytes == 450_560)
        #expect(result.pageOutsBytes == 180_224)
        #expect(result.pageInsBytesPerSecond == 20_480)
        #expect(result.pageOutsBytesPerSecond == 8_192)
    }

    @Test func pagingRateIsUnavailableWithoutAValidBaseline() {
        let current = MemoryPagingSnapshot(timestamp: 10, pageIns: 5, pageOuts: 2)
        let first = MemoryCalculations.paging(current: current, previous: nil, pageSize: 4_096)
        let regressed = MemoryCalculations.paging(
            current: current,
            previous: .init(timestamp: 10, pageIns: 6, pageOuts: 3),
            pageSize: 4_096
        )

        #expect(first.pageInsBytesPerSecond == nil)
        #expect(first.pageOutsBytesPerSecond == nil)
        #expect(regressed.pageInsBytesPerSecond == nil)
        #expect(regressed.pageOutsBytesPerSecond == nil)
    }
}
