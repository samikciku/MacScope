import Foundation
import Testing
@testable import MacScope

@MainActor
struct GPUDataSourcePolicyTests {
    @Test func newInstallDefaultsToPublicMetal() {
        let suiteName = "MacScopeTests.GPUDataSource.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(GPUViewModel(defaults: defaults).source == .metal)
    }

    @Test func disallowedPersistedExperimentalSourceFallsBackToMetal() {
        let suiteName = "MacScopeTests.GPUDataSource.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(GPUDataSource.experimentalIORegistry.rawValue, forKey: "gpu.dataSource")
        let viewModel = GPUViewModel(defaults: defaults)
        viewModel.enforceAllowedSources(experimentalEnabled: false, helperEnabled: false)
        #expect(viewModel.source == .metal)
    }
}
