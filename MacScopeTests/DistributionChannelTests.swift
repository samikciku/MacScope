import Testing
@testable import MacScope

@Suite("Distribution channel")
struct DistributionChannelTests {
    @Test("Store policy never exposes privileged or experimental GPU sources")
    func storePolicyIsRestricted() {
        #if MAC_APP_STORE
        #expect(DistributionChannel.isMacAppStore)
        #expect(!DistributionChannel.allowsExperimentalGPU)
        #expect(!DistributionChannel.allowsPrivilegedGPUHelper)
        #expect(!DistributionChannel.allowsProcessInspection)
        #expect(!DistributionChannel.allowsProcessActions)
        #expect(!DistributionChannel.allowsPerProcessNetwork)
        #else
        #expect(!DistributionChannel.isMacAppStore)
        #expect(DistributionChannel.allowsExperimentalGPU)
        #expect(DistributionChannel.allowsPrivilegedGPUHelper)
        #expect(DistributionChannel.allowsProcessInspection)
        #expect(DistributionChannel.allowsProcessActions)
        #expect(DistributionChannel.allowsPerProcessNetwork)
        #endif
    }
}
