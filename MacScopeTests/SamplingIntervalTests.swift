import Testing
import Foundation
@testable import MacScope

struct SamplingIntervalTests {
    @Test func exposesTheSpecifiedRefreshChoices() {
        #expect(SamplingInterval.allCases.map(\.rawValue) == [0.5, 1, 2, 5])
    }

    @Test @MainActor func persistsRefreshAndMenuBarPreferences() {
        let suiteName = "MacScopeTests.MonitoringSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = MonitoringSettings(defaults: defaults)
        settings.refreshInterval = .fiveSeconds
        settings.showMenuBarItem = true
        settings.appearance = .dark
        settings.cpuAlertEnabled = true
        settings.cpuAlertThreshold = 0.8
        settings.swapAlertEnabled = true
        settings.thermalAlertEnabled = true
        settings.diskAlertEnabled = true
        settings.diskAlertThreshold = 0.85
        settings.batteryAlertEnabled = true
        settings.batteryAlertThreshold = 0.15
        settings.swapAlertThresholdGB = 4
        settings.alertDuration = 60
        settings.alertCooldown = 300
        settings.compactAlwaysOnTop = false
        settings.compactOpacity = 0.75
        settings.compactShowGPU = true
        settings.compactShowSwap = false
        settings.hogMemoryThresholdGB = 6
        settings.hogCPUThresholdPercent = 250
        settings.hogDiskThresholdMBps = 80
        settings.hogNetworkThresholdMBps = 40
        settings.hogPowerThresholdWatts = 15
        settings.hogAlertsEnabled = true

        let restored = MonitoringSettings(defaults: defaults)
        #expect(restored.refreshInterval == .fiveSeconds)
        #expect(restored.showMenuBarItem)
        #expect(restored.appearance == .dark)
        #expect(restored.cpuAlertEnabled)
        #expect(restored.cpuAlertThreshold == 0.8)
        #expect(restored.swapAlertEnabled)
        #expect(restored.thermalAlertEnabled)
        #expect(restored.diskAlertEnabled)
        #expect(restored.diskAlertThreshold == 0.85)
        #expect(restored.batteryAlertEnabled)
        #expect(restored.batteryAlertThreshold == 0.15)
        #expect(restored.swapAlertThresholdGB == 4)
        #expect(restored.alertDuration == 60)
        #expect(restored.alertCooldown == 300)
        #expect(!restored.compactAlwaysOnTop)
        #expect(restored.compactOpacity == 0.75)
        #expect(restored.compactShowGPU)
        #expect(!restored.compactShowSwap)
        #expect(restored.hogMemoryThresholdGB == 6)
        #expect(restored.hogCPUThresholdPercent == 250)
        #expect(restored.hogDiskThresholdMBps == 80)
        #expect(restored.hogNetworkThresholdMBps == 40)
        #expect(restored.hogPowerThresholdWatts == 15)
        #expect(restored.hogAlertsEnabled)
    }
}
