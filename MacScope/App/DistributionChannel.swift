import Foundation

/// Compile-time release policy shared by UI and services.
///
/// The Mac App Store configuration defines `MAC_APP_STORE`. Keep Store-only
/// restrictions here so direct and Store builds cannot silently drift apart.
enum DistributionChannel {
    #if MAC_APP_STORE
    static let isMacAppStore = true
    static let allowsExperimentalGPU = false
    static let allowsPrivilegedGPUHelper = false
    static let allowsProcessInspection = false
    static let allowsProcessActions = false
    static let allowsPerProcessNetwork = false
    #else
    static let isMacAppStore = false
    static let allowsExperimentalGPU = true
    static let allowsPrivilegedGPUHelper = true
    static let allowsProcessInspection = true
    static let allowsProcessActions = true
    static let allowsPerProcessNetwork = true
    #endif
}
