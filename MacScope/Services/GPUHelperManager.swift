import Foundation
import Security
import ServiceManagement

@MainActor
final class GPUHelperManager: ObservableObject {
    enum State: Equatable {
        case unavailable(String)
        case notRegistered
        case requiresApproval
        case enabled
        case notFound

        var title: String {
            switch self {
            case .unavailable: "Unavailable"
            case .notRegistered: "Not installed"
            case .requiresApproval: "Approval required"
            case .enabled: "Enabled"
            case .notFound: "Helper missing"
            }
        }
    }

    static let plistName = "com.macscope.GPUMetricsHelper.plist"
    @Published private(set) var state: State = .notRegistered
    @Published private(set) var message: String?
    private let service = SMAppService.daemon(plistName: plistName)

    init() { refresh() }

    func refresh() {
        guard Self.developerTeamIdentifier() != nil else {
            state = .unavailable("A Developer ID–signed build is required before the root helper can safely authenticate MacScope.")
            return
        }
        switch service.status {
        case .notRegistered: state = .notRegistered
        case .enabled: state = .enabled
        case .requiresApproval: state = .requiresApproval
        case .notFound: state = .notFound
        @unknown default: state = .notFound
        }
    }

    func register() {
        guard Self.developerTeamIdentifier() != nil else { refresh(); return }
        do {
            try service.register()
            message = "Helper submitted. Approve MacScope in System Settings if requested."
        } catch {
            message = error.localizedDescription
        }
        refresh()
    }

    func unregister() {
        do {
            try service.unregister()
            message = "GPU helper removed."
        } catch {
            message = error.localizedDescription
        }
        refresh()
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func developerTeamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dictionary = information as? [CFString: Any],
              let team = dictionary[kSecCodeInfoTeamIdentifier] as? String,
              !team.isEmpty else { return nil }
        return team
    }
}
