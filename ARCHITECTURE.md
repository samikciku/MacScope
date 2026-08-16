# Architecture

MacScope is a native SwiftUI executable package organized into five layers:

- `MacScope/Monitoring`: actor-isolated collectors and deterministic calculations for Mach, libproc, IOKit, Metal, `getifaddrs`, Dispatch memory pressure, and `nettop` data.
- `MacScope/Models`: immutable, sendable snapshots and explicit availability states.
- `MacScope/ViewModels`: main-actor presentation state, bounded histories, filtering, and user actions.
- `MacScope/Services`: process grouping/hierarchy, alerts, metadata resolution, and safety-gated termination.
- `MacScope/Views`: SwiftUI screens observing shared view models.

`AppState` owns shared view models. `MonitoringCoordinator` owns recurring tasks so changing screens, opening the menu-bar popover, or showing the compact window does not duplicate system collectors.

## Data principles

- A missing or unsupported metric is represented explicitly, never as a fabricated numeric zero.
- Histories use bounded ring buffers.
- Process identity is PID plus start time to defend against PID reuse.
- Faster system refresh settings do not force expensive process or disk enumeration at the same rate.
- Storage scanning and process/network attribution run away from the main actor.

## Process control

`ProcessTerminationPolicy` rejects protected targets. `ProcessTerminationService` re-reads process identity immediately before signaling. Normal termination uses `SIGTERM`; `SIGKILL` is a separately confirmed second stage only for a stable process that remains alive.

## Tests

`MacScopeTests` contains deterministic calculation, parsing, policy, grouping, hierarchy, and bounded-history tests plus read-only live integration coverage. The termination integration test creates and terminates only its own `/bin/sleep` child. The storage scanner test operates only inside a uniquely named temporary directory.
