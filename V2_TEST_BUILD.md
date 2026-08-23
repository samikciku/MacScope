# MacScope V2.0.0 Test Build

## Artifacts

- App: `dist/MacScope.app`
- DMG: `dist/MacScope-v2.0.0-test.dmg`
- ZIP: `dist/MacScope-v2.0.0-test.zip`
- Bundle identifier: `com.macscope.app`
- Marketing version: `2.0.0`
- Build number: `2`
- Minimum macOS: 14.0
- Architecture: Apple Silicon (`arm64`)
- DMG SHA-256: `c97c0236383ac6738d752da59d9a4282a547f765f3663257945b1e1da493857f`
- ZIP SHA-256: `b918ef7076d24bbc9b0e14b2a874dcc25521b87456f204ca01a37480775c6959`

The DMG was independently verified with `hdiutil verify`. The ZIP was extracted into a temporary directory and its plist, version, architecture, and strict code signature were checked independently. The packaged app also completed a controlled GUI launch and graceful-quit smoke test.

## Install and run

1. Prefer the DMG if ZIP extraction is unreliable.
2. Open `MacScope-v2.0.0-test.dmg` and copy `MacScope.app` to `/Applications`.
3. Open MacScope. This local test build is ad-hoc signed and not notarized, so Control-click the app, choose **Open**, and confirm once if Gatekeeper asks.
4. Never disable Gatekeeper globally.

## V2 test focus

- Verify the sidebar contains only Overview, Applications, Performance, Storage, Network, Events, and Settings. Confirm each Overview card opens the visible parent workflow with the correct detail tab selected.
- From Applications and Memory, verify `.app` groups say **Quit** and can display the application's own unsaved-work prompt. Confirm an unrecognized application produces a no-action message rather than silently falling back to process signals, while command-line groups retain the explicit **End All** path.
- In Applications → MacScope, verify MacScope's own footprint and history populate. In Settings → Diagnostics, verify collector timings/status populate and the copied report contains no process names, usernames, arguments, file paths, or endpoints.
- Sleep and wake the Mac, then confirm monitoring resumes, lifecycle returns to Running, and the first post-wake CPU, paging, disk, process, and network rates do not include time spent asleep.
- Open **Resource Hogs**, adjust each threshold, filter by category, and search by application/user.
- Enable sustained Resource Hog alerts and verify duration/cooldown behavior with a disposable workload.
- Open Process Details and check signature metadata, redacted launch arguments, and visible network endpoints. Review argument output before sharing it; redaction is best-effort.
- Open GPU, switch between Metal metadata and Experimental live metrics, and verify utilization, renderer/tiler activity, GPU memory, core count, and history. Confirm the experimental warning remains visible.
- Select Advanced Helper and confirm this ad-hoc test build reports that Developer ID signing is required; it must not offer privileged installation. Test helper registration only from a Developer ID–signed and notarized build installed in `/Applications`.
- Verify protected and confirmed **End Task** behavior from Process Details.
- Exercise Timeline type/severity filters and search.
- On a MacBook, connect/disconnect AC power, change charging state, and toggle Low Power Mode; verify only actual transitions appear.
- Use VoiceOver on Timeline, Resource Hogs, launch arguments, and open connections; confirm state is understandable without relying on color.
- Recheck Overview navigation, Storage analysis/Trash, Network attribution, Energy, alerts, compact mode, and menu-bar mode.
- Leave MacScope running for at least 30 minutes and note responsiveness, CPU use, memory growth, and unavailable fields.
- In Memory, click **Used**, switch between Applications and Processes and among the classification filters, and confirm lower-impact suggestions appear only after enough recent history is collected. Expand a multi-process app such as Firefox, hover group/member assessments for their reasons, and verify both individual and group termination require confirmation and warn about unsaved work.
- After ending a disposable task from Memory, wait for the measurement report. Confirm estimated resident memory is kept separate from measured Available and Free/Purgeable changes, and that the explanation remains sensible when macOS retains released pages as reusable cache.

## Known limitations

- This build is locally ad-hoc signed, not Developer ID signed or notarized.
- It is built for Apple Silicon only.
- Whole-system GPU utilization remains unsupported; Metal device metadata is shown.
- Some process, launch-argument, connection, swap, energy, or I/O fields can be unavailable because of macOS permissions.
- Launch-argument redaction covers common secret formats but cannot guarantee detection of every credential.
- Memory pressure remains unavailable until macOS emits the first public pressure event.
- Launch at login is not included.

## Remove or roll back

Quit MacScope and move `MacScope.app` to Trash. To reinstall V1 for comparison, use one of the preserved V1 artifacts in `dist/`. Preferences are shared by bundle identifier; reset them only after quitting with:

```sh
defaults delete com.macscope.app
```
