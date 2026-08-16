# Installing MacScope

## Requirements

- Apple Silicon Mac
- macOS 14 Sonoma or later
- Xcode with the macOS SDK when building from source

## Install a release build when available

1. Open the repository's **Releases** page on GitHub and confirm a release has been published.
2. Download the newest `.dmg` asset.
3. Open the disk image and copy `MacScope.app` to `/Applications`.
4. Open MacScope. For an ad-hoc signed test build, Control-click the app, choose **Open**, and confirm once if Gatekeeper asks. Never disable Gatekeeper globally.

Public test builds may be ad-hoc signed and are not necessarily notarized. Check the release notes and SHA-256 checksum before opening a downloaded artifact.

## Build and run from source

Clone the repository, enter it, and build with Xcode's toolchain:

```sh
git clone https://github.com/samikciku/MacScope.git
cd MacScope
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --disable-sandbox MacScope
```

You can also open `Package.swift` directly in Xcode and run the `MacScope` executable scheme.

## Build a local test app

```sh
./Packaging/package-test-app.sh
```

The script creates an optimized, ad-hoc signed app and ZIP in `dist/`. These generated files are intentionally excluded from Git.

## Permissions and feature notes

- MacScope does not require an administrator password for normal operation.
- Some root-owned or protected processes cannot be inspected or terminated.
- **End Task** sends `SIGTERM` only after PID/start-time identity validation. Force Quit is offered only after the same process remains alive.
- The Disk analyzer scans only a folder you explicitly choose and moves confirmed items to macOS Trash.
- Per-process network attribution uses the built-in `/usr/bin/nettop`; macOS may deny it in restricted environments.
- Whole-system GPU utilization is unavailable because there is no suitable public API for a normal distributable app. MacScope does not fabricate a value.

## Uninstall

Quit MacScope and move `MacScope.app` to Trash. To remove its preferences as well:

```sh
defaults delete com.macscope.app
```

That command affects only MacScope's preference domain.
