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
- DMG SHA-256: `6042e544684b8bc1662f7589f10e91762b71a9cad0c0cf8cd04cc3b976283382`
- ZIP SHA-256: `4f3d6944d504dd33d1fdcdf7b333bbbedade8a3af24ce91dd0bab6fbc4f22cd8`

The DMG was independently verified with `hdiutil verify`. The ZIP was extracted into a temporary directory and its plist, version, architecture, and strict code signature were checked independently. The packaged app also completed a controlled GUI launch and graceful-quit smoke test.

## Install and run

1. Prefer the DMG if ZIP extraction is unreliable.
2. Open `MacScope-v2.0.0-test.dmg` and copy `MacScope.app` to `/Applications`.
3. Open MacScope. This local test build is ad-hoc signed and not notarized, so Control-click the app, choose **Open**, and confirm once if Gatekeeper asks.
4. Never disable Gatekeeper globally.

## V2 test focus

- Verify the sidebar contains only Overview, Applications, Performance, Disk, Network, Events, and Settings. Confirm the hub tabs expose the former detailed categories and Overview's condition card opens the recommended workflow.
- From Applications and Memory, verify `.app` groups say **Quit** and can display the application's own unsaved-work prompt. Confirm an unrecognized application produces a no-action message rather than silently falling back to process signals, while command-line groups retain the explicit **End All** path.
- In Applications → MacScope, verify collector timings and failure states populate. Sleep and wake the Mac, then confirm monitoring resumes, the lifecycle returns to Running, and charts do not show runaway catch-up sampling.
- Open **Resource Hogs**, adjust each threshold, filter by category, and search by application/user.
- Enable sustained Resource Hog alerts and verify duration/cooldown behavior with a disposable workload.
- Open Process Details and check signature metadata, redacted launch arguments, and visible network endpoints. Review argument output before sharing it; redaction is best-effort.
- Open GPU, switch between Metal metadata and Experimental live metrics, and verify utilization, renderer/tiler activity, GPU memory, core count, and history. Confirm the experimental warning remains visible.
- Select Advanced Helper and confirm this ad-hoc test build reports that Developer ID signing is required; it must not offer privileged installation. Test helper registration only from a Developer ID–signed and notarized build installed in `/Applications`.
- Verify protected and confirmed **End Task** behavior from Process Details.
- Exercise Timeline type/severity filters and search.
- On a MacBook, connect/disconnect AC power, change charging state, and toggle Low Power Mode; verify only actual transitions appear.
- Use VoiceOver on Timeline, Resource Hogs, launch arguments, and open connections; confirm state is understandable without relying on color.
- Recheck Dashboard navigation, Disk analysis/Trash, Network attribution, Energy, alerts, compact mode, and menu-bar mode.
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
