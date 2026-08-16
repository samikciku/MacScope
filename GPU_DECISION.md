# GPU Monitoring Decision

## V1 decision

MacScope uses the public Metal API to discover GPU devices and their supported static properties. It does not report a system utilization percentage because no reliable public API compatible with the current distribution-neutral design was established.

The UI represents utilization as `unsupported`; it never substitutes zero or an invented percentage.

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
