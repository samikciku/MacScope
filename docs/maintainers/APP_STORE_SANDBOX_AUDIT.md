# Mac App Store Sandbox Capability Audit

This matrix records a read-only run of the `MacScope AppStore` scheme on
August 17, 2026. The app was ad-hoc signed with
`Packaging/MacScope-AppStore.entitlements`, launched through Launch Services,
and confirmed to have `APP_SANDBOX_CONTAINER_ID` at runtime.

The opt-in audit is enabled only when `MACSCOPE_SANDBOX_AUDIT=1`. It writes a
sanitized JSON report to the app container at:

```text
~/Library/Containers/com.macscope.app/Data/Library/Application Support/MacScope/sandbox-capability-audit.json
```

The report contains capability states and aggregate counts only. It never
records process names, users, arguments, paths, endpoints, or sampled values.

## Measured matrix

| Capability | Result | Evidence / product decision |
| --- | --- | --- |
| App Sandbox | Pass | Runtime container environment was present. |
| CPU totals and per-core load | Pass | 10 cores returned. Keep. |
| Memory and swap | Pass | Mach host statistics and `vm.swapusage` returned. Keep. |
| Process enumeration | Fail | `libproc` produced zero visible process snapshots. Remove process workflows from Store navigation and stop polling. |
| System metadata | Pass | Public system information returned. Keep. |
| Startup disk capacity and aggregate I/O | Pass | Capacity plus nine IOKit block devices returned. Keep. |
| Aggregate network interfaces | Pass | Public interface counters returned. Keep. |
| Per-process network attribution | Fail | `nettop` reported `NStatManagerCreate failed`. Remove from Store UI and stop invoking it. |
| Public Metal GPU metadata | Pass | One Metal device returned. Keep. |
| Own-process launch arguments | Pass | One bounded argument returned. Cross-process access remains unavailable because process enumeration fails. |
| Connection inspection | Fail | `lsof` reported `Operation not permitted`. Remove process details with the other process workflows. |
| User-selected storage scan and Trash | Manual | Requires Open Panel, security-scoped access, recursive scanning, and Trash testing from the signed UI. |
| Process termination | Not tested | Automated audit is intentionally non-destructive. The Store policy disables process actions. |
| Privileged GPU helper | Excluded | Store policy removes experimental/helper choices and does not embed the daemon. |

Counts are hardware- and session-specific; availability is the relevant result.
Repeat the audit on every supported macOS major version and on a clean account.

## Remaining hands-on gates

1. Select a folder outside the container and confirm the scanner can read it.
2. Relaunch the app and determine whether persistent access is required. If it
   is, implement security-scoped bookmarks before claiming persistence.
3. Move a controlled test file to Trash and restore it.
4. Verify notifications, menu-bar behavior, sleep/wake, VoiceOver, and a
   sustained Instruments run in the signed Store configuration.
5. Repeat using an Apple Development or Mac App Distribution signature before
   TestFlight; ad-hoc signing is evidence of sandbox behavior, not Store trust.

## Rollback

Remove `AppStoreSandboxAudit.swift` and its call from `MacScopeApp.swift`, then
regenerate `MacScope.xcodeproj`. Revert the Store feature-policy flags and UI
gates only if Apple provides an approved entitlement or replacement public API
and a new signed audit demonstrates the capability.
