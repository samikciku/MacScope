# GPU Monitoring Decision

## V1 decision

MacScope uses the public Metal API to discover GPU devices and their supported static properties. Metal mode does not report a system utilization percentage because no reliable public API compatible with the current distribution-neutral design was established.

V2 also offers an explicitly labeled experimental IORegistry mode on compatible Apple Silicon Macs. It reads the AGX driver's published `PerformanceStatistics` fields for device, renderer, and tiler utilization plus memory and core-count information. This requires no administrator access, but the field names are undocumented and can change between macOS releases. Users can switch back to public-only Metal metadata at any time.

Advanced Helper mode is packaged as a separate, optional `SMAppService` LaunchDaemon. It runs as root only after administrator approval, accepts XPC connections matching MacScope's Developer ID identifier and team, and exposes one read-only GPU sampling method. The method invokes `/usr/bin/powermetrics` with an immutable argument list, five-second timeout, and bounded output. The entire GUI app remains unprivileged. Ad-hoc builds fail closed because they have no trustworthy team identity.

The UI represents utilization as `unsupported` in Metal mode and as unavailable when the experimental fields are absent; it never substitutes zero or an invented percentage.

## Why Metal counters are insufficient

Metal counter sample buffers collect counter data at sampling points encoded into this application's own render, compute, or blit command passes. They are useful for profiling work submitted by MacScope itself, but they do not provide a supported arbitrary whole-system GPU busy percentage.

Apple documentation:

- https://developer.apple.com/documentation/metal/gpu-counters-and-counter-sample-buffers
- https://developer.apple.com/documentation/metal/sampling-gpu-data-into-counter-sample-buffers

## Rejected V1 approaches

- Private or undocumented IOKit performance keys
- Repeated shell execution of tools such as `ioreg` or `powermetrics`
- Administrator/root privilege escalation
- Treating missing information as zero utilization

## Future review condition

Revisit this decision if Apple publishes a supported API for whole-system GPU utilization or after the project deliberately chooses a distribution model with a documented, supportable alternative.
