# MacScope

[![CI](https://github.com/samikciku/MacScope/actions/workflows/ci.yml/badge.svg)](https://github.com/samikciku/MacScope/actions/workflows/ci.yml)
[![License: GPL v3+](https://img.shields.io/badge/License-GPLv3%2B-blue.svg)](LICENSE)

MacScope is a native SwiftUI macOS resource monitor for macOS 14 and later. It reads memory and CPU statistics through Mach APIs, enumerates processes with `libproc`, discovers GPU devices through Metal, and never fabricates unavailable utilization data. The GPU screen offers public Metal metadata, an explicitly labeled experimental Apple Silicon source, and a Developer ID–gated advanced helper source.

Process views support both individual processes and expandable application aggregates. A dedicated MacScope section exposes the monitor's own memory, CPU, thread count, and bounded history.

Processes also provide a searchable parent/child hierarchy that preserves ancestor context, orphaned processes, and cycle safety without additional monitoring calls.

Every individual process row includes a confirmed **End Task…** action. MacScope sends a normal termination request only after revalidating the process identity, while protecting MacScope itself, PID 1, critical system processes, and root-owned processes.

Application groups such as Firefox also include a confirmed **End All…** action that sends termination requests to every eligible child while skipping protected processes.

Process details include public executable architecture, `.app` bundle identifiers, and on-demand Security-framework signature validation with signing/team identifiers when accessible. Signature results are cached for up to 256 executable paths and are not collected during background process polling. Entitlements and certificate contents are not collected. Opening Process Details also performs bounded, on-demand reads of launch arguments and up to 200 visible listening sockets or active network endpoints. Connection inspection has a five-second timeout and a 1 MiB output ceiling. Arguments are redacted for common credential patterns before display, but redaction is best-effort and output should still be reviewed before sharing. None of these inspections adds background polling.

Configurable sustained CPU and swap alerts provide cooldown and hysteresis, a bounded local event timeline, and optional macOS notifications. A compact floating window can show CPU, RAM, GPU, and swap using the same shared monitoring engine, with persisted opacity and always-on-top preferences.

The Memory screen includes purgeable memory, cumulative page-ins/page-outs, and their bounded per-second activity history. Clicking **Used** opens a largest-first process-memory drill-down with process, PID, user, resident memory, protected task controls, search, and Process Details. It distinguishes visible process resident totals from system-used memory, which also includes kernel, wired/compressed, shared, and cached pages.

The Disk screen reports public startup-volume capacity values plus bounded aggregate block-device read/write history from documented IOKit storage counters. Throughput is labeled as a system aggregate and is not presented as per-volume or per-process usage.

Disk also includes an explicit folder-based storage analyzer. It calculates recursive sizes for the selected folder's immediate files and subfolders, sorts them largest-first, filters by files or folders, and moves confirmed items to macOS Trash rather than permanently deleting them.

The Network screen reports active non-loopback interface totals and bounded aggregate transfer rates using public link-layer counters. It also uses macOS `nettop` snapshots to rank per-process downloads/uploads and offers the same protected, confirmed End Task action. It does not inspect packet contents or remote hosts.

The Battery screen uses public IOKit power-source data for charge, source, charging state, available time estimates, health/capacity fields, adapter wattage, and bounded history. Desktop Macs show an explicit unsupported state.

The Thermal screen records macOS nominal/fair/serious/critical system pressure and Low Power Mode with bounded history. Optional sustained thermal alerts reuse the central alert engine; exact sensor temperatures remain explicitly unavailable.

The Timeline screen combines emitted resource alerts with real thermal, memory-pressure, battery/AC charging, and Low Power Mode transitions in a bounded 500-entry local history. Events can be filtered by type and severity or searched by title/message, with newest-first filtered and total counts. Initial samples establish baselines, so only actual changes generate transition events. It does not persist or transmit event data.

The Energy screen reports public per-process nanojoule-derived power, wakeups, disk rates, and CPU where accessible. These are direct MacScope measurements and are not labeled as Apple's proprietary Energy Impact metric.

The Resource Hogs screen aggregates related application processes and highlights configurable memory, CPU, disk, network, and measured-power threshold violations. Findings can be filtered by category or searched by application/user, show filtered and total counts, and open Process Details for the established safety-gated task controls. Optional sustained application alerts share the global duration, cooldown, notification, and timeline behavior; their internal state is bounded and each evaluation emits at most five new events. The 20 newest Resource Hog events from the existing bounded alert history appear on the same screen. Per-process GPU and swap attribution remain unavailable and are not inferred.

Alert rules cover sustained CPU, swap, thermal pressure, startup-disk usage, and low battery. Direction-aware hysteresis prevents repeated edge-triggering, and unsupported battery state never emits an event.

Public memory-pressure events update normal, warning, and critical state and enter the local timeline only on real transitions.

The Dashboard summarizes memory, CPU, GPU, processes, disk, network, battery, thermal state, top consumers, bounded trends, and the five most recent local events from the same shared monitoring state.

Dashboard cards and charts navigate directly to their detailed category. Top-process rows include the owning user and open the selected process details. Process-oriented tables and lists expose the owner wherever macOS provides it.

V2 diagnostic surfaces provide explicit VoiceOver summaries and do not rely on icon shape, layout, or color alone for severity and state. Timeline events state their severity in text, while Resource Hog findings, launch arguments, connection endpoints, and filtered counts expose combined accessibility labels.

## Requirements

- macOS 14+
- Xcode 16 or later with a Swift 6-compatible macOS SDK for source builds

## Install

MacScope can be built and run from source now. When a prebuilt release is published, download the newest DMG from the repository's GitHub Releases page, open it, and copy `MacScope.app` to `/Applications`. Test releases may be ad-hoc signed rather than notarized; read the release notes and verify the published checksum.

Complete installation, Gatekeeper-safe opening, source-build, permissions, packaging, and uninstall instructions are in [INSTALL.md](INSTALL.md).

Local V2 test-build artifacts and their checksums/test matrix are documented in [V2_TEST_BUILD.md](V2_TEST_BUILD.md). These generated artifacts are ad-hoc signed and are not a notarized public release.

## Build from source

Open `Package.swift` in Xcode, or build from Terminal:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift build --disable-sandbox
```

Optimized build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift build -c release --disable-sandbox
```

## Test

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --disable-sandbox
```

The test suite includes live read-only integration tests and one termination test that creates and terminates only its own controlled `/bin/sleep` child process.

## Privacy and safety

- MacScope does not include analytics or transmit collected monitoring data.
- Network monitoring reads byte counters and does not inspect packet contents. Process Details can show visible endpoint addresses only after the user opens that process; results remain in memory and are not transmitted.
- Disk analysis begins only after you select a folder. Removal is confirmed and uses macOS Trash.
- Process actions are confirmed, safety-gated, and protected against PID reuse.
- Launch arguments are collected only after Process Details opens, bounded in memory, and filtered for common secret patterns before display. They are never persisted or transmitted.
- MacScope does not request an administrator password or attempt to bypass macOS protections.

See [SECURITY.md](SECURITY.md) for security reporting and trust boundaries.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md), [ARCHITECTURE.md](ARCHITECTURE.md), and the [Code of Conduct](CODE_OF_CONDUCT.md) before submitting a substantial change.

## Current limitations

- Metal does not expose whole-system GPU utilization. On compatible Apple Silicon Macs, the GPU screen can instead use an experimental IORegistry source for device, renderer, and tiler utilization, memory, core count, and history. These undocumented AGX fields may disappear or change after macOS updates; select Metal metadata for the stable public-only mode.
- Advanced Helper mode uses an optional root LaunchDaemon registered through `SMAppService` and approved by an administrator. Its XPC listener accepts only the Developer ID–signed MacScope client, and its sole operation runs Apple `powermetrics` with fixed GPU-only arguments, a five-second timeout, and a 1 MiB output limit. Ad-hoc test builds intentionally cannot register it.
- Memory pressure remains unavailable until macOS delivers the first public pressure event; MacScope does not infer a normal state.
- Swap information can be unavailable when an execution sandbox denies `vm.swapusage`.
- Launch at login is not implemented.
- Public distribution still requires Developer ID signing, notarization, broader hardware testing, and final entitlement review.

See [GPU_DECISION.md](GPU_DECISION.md), [PROFILING.md](PROFILING.md), and [RELEASE_PREPARATION.md](RELEASE_PREPARATION.md).

## License

MacScope is free and open-source software under the [GNU General Public License, version 3 or later](LICENSE) (`GPL-3.0-or-later`). Modified versions distributed to others must remain available under the GPL terms.
