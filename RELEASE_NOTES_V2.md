# MacScope 2.0.0

**Open-source Task Manager for Mac**

MacScope 2 expands the native macOS monitor from core CPU, memory, and process visibility into a broader local system-diagnostics application. Collection remains local, bounded, and explicit about unavailable metrics.

## Highlights

- A focused seven-destination navigation model and an Overview diagnosis that states the current condition, supporting evidence, safest recommendation, and relevant details.
- Disk capacity, aggregate storage throughput, and a largest-first folder analyzer with confirmed moves to Trash.
- Network interface throughput and best-effort per-process attribution with protected task termination.
- Battery, charging, Low Power Mode, thermal-pressure, energy, and system-event views.
- Application grouping, process hierarchy, signing metadata, redacted launch arguments, and visible network endpoints.
- Resource Hog analysis and sustained alerts for CPU, memory, disk, network, and measured power.
- Public Metal GPU metadata plus an opt-in experimental Apple Silicon live-metrics source. An advanced helper path remains unavailable in ad-hoc builds.
- Memory-consumer drill-down with conservative application/process classifications, protected termination, pressure guidance, and measured after-action feedback.
- Dashboard navigation, compact monitor, menu-bar monitor, bounded history, and accessibility summaries.
- Wake-safe sampling with generation invalidation, monotonic duration measurement, and reset rate baselines.
- Collector freshness and failure diagnostics in Settings, plus a privacy-sanitized support report.
- Typed workflow routing so Overview links select the visible parent and correct detail tab.
- Verified inline outcomes for process and application quit actions, including still-running and cancelled states.

## Memory recommendations

MacScope classifies memory consumers as Lower-impact candidate, Review manually, Active, or Protected. These are conservative suggestions based on ownership, recent CPU history, known disk activity, resident size, and termination policy. They cannot detect unsaved documents or every form of background work, never claim that termination is lossless, and never end a task automatically.

After confirmed termination, the app reports estimated resident memory separately from measured changes in Available, Free, and Purgeable memory. macOS may keep released pages as reusable cache, so Free memory does not necessarily increase.

## Distribution status

The current `2.0.0-test` artifacts are a beta-quality local test build. They are ad-hoc signed and not notarized. A public release still requires Developer ID signing, Hardened Runtime validation, Apple notarization and stapling, clean-Mac verification, and broader hardware/accessibility testing. Passing repository tests is not a substitute for those external gates.

## Known limitations

- Whole-system GPU utilization is not available through public Metal APIs. Experimental AGX values can change across macOS releases and are limited to compatible Apple Silicon systems.
- Reliable per-process GPU and swap attribution are unavailable and are not inferred.
- Network process attribution is best effort and may be unavailable because of permissions, short-lived connections, or tool limitations.
- Process resident-memory totals do not equal system Used memory because macOS also uses kernel, wired/compressed, shared, and cached pages.
- Memory pressure remains Awaiting Data until macOS emits the first public pressure event.
- Some protected or other-user processes cannot be inspected or terminated.

See [V2_TEST_BUILD.md](V2_TEST_BUILD.md) for installation, checksums, and the hands-on test matrix.
