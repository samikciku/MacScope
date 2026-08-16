# Release Preparation

## V2 test-build status

An Apple Silicon V2.0.0 test `.app` is reproducibly packaged from the optimized SwiftPM build with bundle identifier `com.macscope.app`, compiled app-icon assets, macOS 14 minimum, and a local ad-hoc signature. ZIP and compressed read-only DMG artifacts are integrity-tested, and the app has completed a controlled GUI launch/quit smoke test. These are suitable for local hands-on testing, not trusted public distribution. See `V2_TEST_BUILD.md` for checksums and the test matrix.

## Distribution baseline

Use direct distribution outside the Mac App Store for the first release candidate. MacScope depends on broad process inspection, and App Sandbox compatibility has not been demonstrated. This decision avoids silently shipping a sandboxed build with materially incomplete process data; it does not authorize weakening other macOS protections.

Before release, create a normal macOS app target in Xcode with:

- A unique bundle identifier
- Marketing version and build number
- App icon assets
- Deployment target macOS 14+
- Hardened Runtime enabled
- A deliberate entitlement set with no unnecessary privileges
- Automatic or manual signing for the selected Apple Developer team

The repository can create an ad-hoc signed local `.app`; trusted public distribution still needs a Developer ID archive/sign/notarize pipeline.

## Direct distribution checklist

1. Create and install a Developer ID Application certificate.
2. Build and archive the Release configuration in Xcode.
3. Export using Direct Distribution / Developer ID.
4. Confirm Hardened Runtime and secure timestamp are present.
5. Submit the signed archive/package to Apple’s notary service using Xcode or `notarytool`.
6. Review the complete notarization log, including warnings.
7. Staple the notarization ticket to the distributed artifact.
8. Verify signatures and Gatekeeper assessment on a clean test account/Mac.
9. Re-run termination, restricted-process, menu-bar, launch, and long-duration monitoring tests on the signed build.

Suggested verification commands after an app bundle exists:

```sh
codesign --verify --deep --strict --verbose=2 MacScope.app
spctl --assess --type execute --verbose=4 MacScope.app
xcrun stapler validate MacScope.app
```

Do not place Apple IDs, app-specific passwords, API keys, certificate private keys, or notary credentials in this repository. Store `notarytool` credentials in Keychain or use an approved CI secret store.

## Release blockers

- Create the Xcode macOS app target and archive scheme.
- Choose the final bundle identifier and Apple Developer team.
- Create production icon and metadata assets.
- Complete signed-app Instruments Allocations/Leaks and longer Time Profiler runs.
- Reduce and remeasure the observed ~3.9% one-core steady-state CPU sample.
- Validate direct-distribution entitlements and process visibility on clean Macs.
- Decide whether launch-at-login is in release scope and, if so, implement it with ServiceManagement.

## Apple references

- Developer ID certificates: https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
- Distribution workflows: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
- Notarization: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
