import Testing
@testable import MacScope

struct ByteFormatterTests {
    @Test func formatsMemoryUsingAdaptiveUnits() {
        let result = ByteFormatter.string(fromByteCount: 5_368_709_120)

        #expect(result.contains("GB"))
        #expect(result.hasPrefix("5"))
    }
}
