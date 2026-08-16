# Profiling Report

## Environment

- Date: 2026-08-15
- Hardware: MacBook Air
- macOS: 26.6.1 (25G76)
- Xcode/Instruments: 26.6 / Instruments 16.0 (17F113)
- Build: SwiftPM optimized release executable
- Default sampling: memory/CPU 1 second; processes 2 seconds

## Automated stability run

The release test suite repeatedly samples memory, CPU, and processes concurrently for 300 cycles with 100 ms between cycles. It checks metric ranges and nonempty process results throughout. Histories remain independently constrained by tested 300-element ring buffers.

This is a bounded smoke/stability run, not a substitute for an overnight soak test.

## Time Profiler

A 15-second Time Profiler capture was recorded against the release executable:

- Trace duration: 16.159 seconds; configured measurement limit: 15 seconds
- Running-thread samples: approximately 558 at 1 ms sample weight
- Final steady-state window: 149 ms of samples from 12.0 to 15.869 seconds
- Approximate steady-state CPU: 3.9% of one CPU core

The measurement includes SwiftUI rendering, menu/status infrastructure, and active native collectors. It does **not** meet the aspirational <1% average CPU goal. No unsupported performance claim should be made for V1.

The trace was captured at `/private/tmp/MacScope-Time.trace`; temporary trace files are not release artifacts.

## Leaks

A 15-second Leaks capture was attempted, but Instruments could not acquire the target task port and reported `Failed to attach to target process`. Therefore no leak-free claim can be made from this run.

## Required follow-up measurements

- Run Time Profiler for at least 5–10 minutes after launch and separate launch cost from steady state.
- Inspect process enumeration, icon loading, formatter creation, and SwiftUI chart invalidation as likely optimization areas.
- Run Allocations and Leaks from the Xcode Instruments UI with a signed app target.
- Perform an overnight soak test and compare resident memory at fixed intervals.
- Test Apple Silicon models with different core counts and at least two supported macOS releases.
- Measure with menu-bar mode both enabled and disabled and with every sampling preference.
