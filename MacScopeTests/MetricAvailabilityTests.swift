import Testing
@testable import MacScope

struct MetricAvailabilityTests {
    @Test func unsupportedIsDistinctFromZeroUtilization() {
        let unavailable = MetricAvailability<Double>.unsupported(reason: "No supported source")
        let zero = MetricAvailability<Double>.available(0)

        #expect(unavailable != zero)
    }
}
