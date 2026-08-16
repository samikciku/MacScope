import Foundation
import Testing
import MacScopeHelperShared

struct PowermetricsGPUParserTests {
    @Test func parsesBoundedGPUOnlyMetricsAndConvertsUnits() {
        let timestamp = Date(timeIntervalSince1970: 42)
        let sample = PowermetricsGPUParser.parse(
            """
            GPU Power: 1250 mW
            GPU HW active residency: 37.5%
            GPU HW active frequency: 812 MHz
            """,
            timestamp: timestamp
        )

        #expect(sample.timestamp == timestamp)
        #expect(sample.utilization == 0.375)
        #expect(sample.powerWatts == 1.25)
        #expect(sample.frequencyMHz == 812)
    }

    @Test func leavesAbsentMetricsUnavailableInsteadOfInventingZeroes() {
        let sample = PowermetricsGPUParser.parse("CPU Power: 500 mW")
        #expect(sample.utilization == nil)
        #expect(sample.powerWatts == nil)
        #expect(sample.frequencyMHz == nil)
    }
}
