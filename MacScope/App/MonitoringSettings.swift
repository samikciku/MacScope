import Foundation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum SamplingInterval: Double, CaseIterable, Identifiable, Sendable {
    case halfSecond = 0.5
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5

    var id: Double { rawValue }
    var duration: Duration { .milliseconds(Int(rawValue * 1_000)) }
    var title: String { rawValue == 0.5 ? "0.5 seconds" : "\(Int(rawValue)) seconds" }
}

@MainActor
final class MonitoringSettings: ObservableObject {
    private static let refreshIntervalKey = "monitoring.refreshInterval"
    private static let showMenuBarItemKey = "monitoring.showMenuBarItem"
    private static let appearanceKey = "appearance"
    private static let cpuAlertEnabledKey = "alerts.cpu.enabled"
    private static let cpuAlertThresholdKey = "alerts.cpu.threshold"
    private static let alertDurationKey = "alerts.duration"
    private static let alertCooldownKey = "alerts.cooldown"
    private static let swapAlertEnabledKey = "alerts.swap.enabled"
    private static let swapAlertThresholdKey = "alerts.swap.thresholdGB"
    private static let notificationsEnabledKey = "alerts.notifications.enabled"
    private static let thermalAlertEnabledKey = "alerts.thermal.enabled"
    private static let diskAlertEnabledKey = "alerts.disk.enabled"
    private static let diskAlertThresholdKey = "alerts.disk.threshold"
    private static let batteryAlertEnabledKey = "alerts.battery.enabled"
    private static let batteryAlertThresholdKey = "alerts.battery.threshold"
    private static let compactAlwaysOnTopKey = "compact.alwaysOnTop"
    private static let compactOpacityKey = "compact.opacity"
    private static let compactShowGPUKey = "compact.showGPU"
    private static let compactShowSwapKey = "compact.showSwap"
    private static let hogMemoryThresholdKey = "resourceHogs.memoryThresholdGB"
    private static let hogCPUThresholdKey = "resourceHogs.cpuThresholdPercent"
    private static let hogDiskThresholdKey = "resourceHogs.diskThresholdMBps"
    private static let hogNetworkThresholdKey = "resourceHogs.networkThresholdMBps"
    private static let hogPowerThresholdKey = "resourceHogs.powerThresholdWatts"
    private static let hogAlertsEnabledKey = "resourceHogs.alertsEnabled"
    private static let experimentalGPUEnabledKey = "gpu.experimental.enabled"
    private static let advancedGPUHelperEnabledKey = "gpu.helper.enabled"

    private let defaults: UserDefaults

    @Published var refreshInterval: SamplingInterval {
        didSet {
            defaults.set(refreshInterval.rawValue, forKey: Self.refreshIntervalKey)
        }
    }
    @Published var showMenuBarItem: Bool {
        didSet {
            defaults.set(showMenuBarItem, forKey: Self.showMenuBarItemKey)
        }
    }
    @Published var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        }
    }
    @Published var cpuAlertEnabled: Bool { didSet { persist(cpuAlertEnabled, key: Self.cpuAlertEnabledKey) } }
    @Published var cpuAlertThreshold: Double { didSet { persist(cpuAlertThreshold, key: Self.cpuAlertThresholdKey) } }
    @Published var alertDuration: TimeInterval { didSet { persist(alertDuration, key: Self.alertDurationKey) } }
    @Published var alertCooldown: TimeInterval { didSet { persist(alertCooldown, key: Self.alertCooldownKey) } }
    @Published var swapAlertEnabled: Bool { didSet { persist(swapAlertEnabled, key: Self.swapAlertEnabledKey) } }
    @Published var swapAlertThresholdGB: Double { didSet { persist(swapAlertThresholdGB, key: Self.swapAlertThresholdKey) } }
    @Published var notificationsEnabled: Bool { didSet { persist(notificationsEnabled, key: Self.notificationsEnabledKey) } }
    @Published var thermalAlertEnabled: Bool { didSet { persist(thermalAlertEnabled, key: Self.thermalAlertEnabledKey) } }
    @Published var diskAlertEnabled: Bool { didSet { persist(diskAlertEnabled, key: Self.diskAlertEnabledKey) } }
    @Published var diskAlertThreshold: Double { didSet { persist(diskAlertThreshold, key: Self.diskAlertThresholdKey) } }
    @Published var batteryAlertEnabled: Bool { didSet { persist(batteryAlertEnabled, key: Self.batteryAlertEnabledKey) } }
    @Published var batteryAlertThreshold: Double { didSet { persist(batteryAlertThreshold, key: Self.batteryAlertThresholdKey) } }
    @Published var compactAlwaysOnTop: Bool { didSet { persist(compactAlwaysOnTop, key: Self.compactAlwaysOnTopKey) } }
    @Published var compactOpacity: Double { didSet { persist(compactOpacity, key: Self.compactOpacityKey) } }
    @Published var compactShowGPU: Bool { didSet { persist(compactShowGPU, key: Self.compactShowGPUKey) } }
    @Published var compactShowSwap: Bool { didSet { persist(compactShowSwap, key: Self.compactShowSwapKey) } }
    @Published var hogMemoryThresholdGB: Double { didSet { persist(hogMemoryThresholdGB, key: Self.hogMemoryThresholdKey) } }
    @Published var hogCPUThresholdPercent: Double { didSet { persist(hogCPUThresholdPercent, key: Self.hogCPUThresholdKey) } }
    @Published var hogDiskThresholdMBps: Double { didSet { persist(hogDiskThresholdMBps, key: Self.hogDiskThresholdKey) } }
    @Published var hogNetworkThresholdMBps: Double { didSet { persist(hogNetworkThresholdMBps, key: Self.hogNetworkThresholdKey) } }
    @Published var hogPowerThresholdWatts: Double { didSet { persist(hogPowerThresholdWatts, key: Self.hogPowerThresholdKey) } }
    @Published var hogAlertsEnabled: Bool { didSet { persist(hogAlertsEnabled, key: Self.hogAlertsEnabledKey) } }
    @Published var experimentalGPUEnabled: Bool {
        didSet {
            persist(experimentalGPUEnabled, key: Self.experimentalGPUEnabledKey)
            if !experimentalGPUEnabled { advancedGPUHelperEnabled = false }
        }
    }
    @Published var advancedGPUHelperEnabled: Bool {
        didSet { persist(advancedGPUHelperEnabled, key: Self.advancedGPUHelperEnabledKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: Self.refreshIntervalKey)
        refreshInterval = SamplingInterval(rawValue: stored) ?? .oneSecond
        showMenuBarItem = defaults.bool(forKey: Self.showMenuBarItemKey)
        appearance = defaults.string(forKey: Self.appearanceKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        cpuAlertEnabled = defaults.bool(forKey: Self.cpuAlertEnabledKey)
        cpuAlertThreshold = Self.storedDouble(defaults, key: Self.cpuAlertThresholdKey, fallback: 0.9)
        alertDuration = Self.storedDouble(defaults, key: Self.alertDurationKey, fallback: 120)
        alertCooldown = Self.storedDouble(defaults, key: Self.alertCooldownKey, fallback: 900)
        swapAlertEnabled = defaults.bool(forKey: Self.swapAlertEnabledKey)
        swapAlertThresholdGB = Self.storedDouble(defaults, key: Self.swapAlertThresholdKey, fallback: 8)
        notificationsEnabled = defaults.bool(forKey: Self.notificationsEnabledKey)
        thermalAlertEnabled = defaults.bool(forKey: Self.thermalAlertEnabledKey)
        diskAlertEnabled = defaults.bool(forKey: Self.diskAlertEnabledKey)
        diskAlertThreshold = Self.storedDouble(defaults, key: Self.diskAlertThresholdKey, fallback: 0.9)
        batteryAlertEnabled = defaults.bool(forKey: Self.batteryAlertEnabledKey)
        batteryAlertThreshold = Self.storedDouble(defaults, key: Self.batteryAlertThresholdKey, fallback: 0.2)
        compactAlwaysOnTop = defaults.object(forKey: Self.compactAlwaysOnTopKey) as? Bool ?? true
        compactOpacity = Self.storedDouble(defaults, key: Self.compactOpacityKey, fallback: 0.94)
        compactShowGPU = defaults.bool(forKey: Self.compactShowGPUKey)
        compactShowSwap = defaults.object(forKey: Self.compactShowSwapKey) as? Bool ?? true
        hogMemoryThresholdGB = Self.storedDouble(defaults, key: Self.hogMemoryThresholdKey, fallback: 8)
        hogCPUThresholdPercent = Self.storedDouble(defaults, key: Self.hogCPUThresholdKey, fallback: 300)
        hogDiskThresholdMBps = Self.storedDouble(defaults, key: Self.hogDiskThresholdKey, fallback: 100)
        hogNetworkThresholdMBps = Self.storedDouble(defaults, key: Self.hogNetworkThresholdKey, fallback: 50)
        hogPowerThresholdWatts = Self.storedDouble(defaults, key: Self.hogPowerThresholdKey, fallback: 20)
        hogAlertsEnabled = defaults.bool(forKey: Self.hogAlertsEnabledKey)
        experimentalGPUEnabled = defaults.bool(forKey: Self.experimentalGPUEnabledKey)
        advancedGPUHelperEnabled = defaults.bool(forKey: Self.advancedGPUHelperEnabledKey)
    }

    var processRefreshDuration: Duration {
        .milliseconds(Int(Swift.max(2, refreshInterval.rawValue) * 1_000))
    }

    var cpuAlertRule: ResourceAlertRule {
        ResourceAlertRule(
            enabled: cpuAlertEnabled,
            threshold: cpuAlertThreshold,
            duration: alertDuration,
            cooldown: alertCooldown,
            hysteresis: 0.05
        )
    }

    var swapAlertRule: ResourceAlertRule {
        ResourceAlertRule(
            enabled: swapAlertEnabled,
            threshold: swapAlertThresholdGB * 1_000_000_000,
            duration: alertDuration,
            cooldown: alertCooldown,
            hysteresis: 500_000_000
        )
    }

    var thermalAlertRule: ResourceAlertRule {
        ResourceAlertRule(
            enabled: thermalAlertEnabled,
            threshold: Double(ThermalStats.State.serious.rawValue),
            duration: alertDuration,
            cooldown: alertCooldown,
            hysteresis: 1
        )
    }

    var diskAlertRule: ResourceAlertRule {
        ResourceAlertRule(
            enabled: diskAlertEnabled,
            threshold: diskAlertThreshold,
            duration: alertDuration,
            cooldown: alertCooldown,
            hysteresis: 0.02
        )
    }

    var batteryAlertRule: ResourceAlertRule {
        ResourceAlertRule(
            enabled: batteryAlertEnabled,
            threshold: batteryAlertThreshold,
            duration: alertDuration,
            cooldown: alertCooldown,
            hysteresis: 0.05,
            direction: .below
        )
    }

    var resourceHogThresholds: ResourceHogThresholds {
        ResourceHogThresholds(
            memoryBytes: UInt64(Swift.max(0.25, hogMemoryThresholdGB) * 1_000_000_000),
            cpuPercent: Swift.max(10, hogCPUThresholdPercent),
            diskBytesPerSecond: Swift.max(1, hogDiskThresholdMBps) * 1_000_000,
            networkBytesPerSecond: Swift.max(1, hogNetworkThresholdMBps) * 1_000_000,
            powerWatts: Swift.max(0.1, hogPowerThresholdWatts)
        )
    }

    private func persist(_ value: Any, key: String) {
        defaults.set(value, forKey: key)
    }

    private static func storedDouble(_ defaults: UserDefaults, key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
