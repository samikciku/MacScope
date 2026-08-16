# Contributing to MacScope

Contributions are welcome. Please open an issue before a large architectural change so implementation and macOS compatibility can be discussed first.

## Development setup

1. Use macOS 14 or later with Xcode installed.
2. Fork and clone the repository.
3. Create a focused branch from the default branch.
4. Build and test with Xcode's selected toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --disable-sandbox
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox
```

## Project expectations

- Use documented public macOS APIs whenever possible.
- Never fabricate unavailable metrics or silently replace them with zero.
- Preserve PID plus process-start-time validation for process-control actions.
- Keep destructive operations user initiated, confirmed, narrowly scoped, and recoverable where possible.
- Do not add telemetry, packet-content inspection, private credentials, signing material, or undocumented privileged helpers.
- Add deterministic tests for calculations and parsers. Keep live integration checks read-only except for tests that create and control their own child process or temporary data.
- Maintain VoiceOver labels, keyboard behavior, and sufficient contrast for UI changes.
- Update user documentation when behavior, requirements, or limitations change.

## Pull requests

Keep pull requests focused and describe:

- what changed and why;
- user-visible behavior and safety implications;
- tests and manual verification performed;
- relevant limitations or follow-up work.

By contributing, you agree that your contribution is licensed under the GNU General Public License, version 3 or later (`GPL-3.0-or-later`).
