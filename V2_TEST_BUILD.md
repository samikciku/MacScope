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
- DMG SHA-256: `9b025772282ea5b874f554d679636f20a6ed50a1d721cd6e9a30c245bfa199b3`
- ZIP SHA-256: `f0b523ac3e7da910591868d341ed35691fbdd5182a35bdadcd8e5ed187c8af6f`

The DMG was independently verified with `hdiutil verify`. The ZIP was extracted into a temporary directory and its plist, version, architecture, and strict code signature were checked independently. The packaged app also completed a controlled GUI launch and graceful-quit smoke test.

## Install and run

1. Prefer the DMG if ZIP extraction is unreliable.
2. Open `MacScope-v2.0.0-test.dmg` and copy `MacScope.app` to `/Applications`.
3. Open MacScope. This local test build is ad-hoc signed and not notarized, so Control-click the app, choose **Open**, and confirm once if Gatekeeper asks.
4. Never disable Gatekeeper globally.

## V2 test focus

- Open **Resource Hogs**, adjust each threshold, filter by category, and search by application/user.
- Enable sustained Resource Hog alerts and verify duration/cooldown behavior with a disposable workload.
- Open Process Details and check signature metadata, redacted launch arguments, and visible network endpoints. Review argument output before sharing it; redaction is best-effort.
- Verify protected and confirmed **End Task** behavior from Process Details.
- Exercise Timeline type/severity filters and search.
- On a MacBook, connect/disconnect AC power, change charging state, and toggle Low Power Mode; verify only actual transitions appear.
- Use VoiceOver on Timeline, Resource Hogs, launch arguments, and open connections; confirm state is understandable without relying on color.
- Recheck Dashboard navigation, Disk analysis/Trash, Network attribution, Energy, alerts, compact mode, and menu-bar mode.
- Leave MacScope running for at least 30 minutes and note responsiveness, CPU use, memory growth, and unavailable fields.

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
