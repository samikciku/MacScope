# Releasing MacScope

This is a maintainer checklist for producing a trusted public MacScope release. Local test artifacts are suitable for hands-on testing, but they are not a substitute for Developer ID signing and Apple notarization.

## V2 test-build status

The repository reproducibly packages an optimized Apple Silicon V2.0.0 test app with bundle identifier `com.macscope.app`, macOS 14 minimum, compiled icon assets, and a local ad-hoc signature. CI rebuilds and verifies the app metadata, signature structure, ZIP, and DMG on every pull request.

See [`V2_TEST_BUILD.md`](../../V2_TEST_BUILD.md) for checksums and the test matrix, and [`RELEASE_NOTES_V2.md`](../../RELEASE_NOTES_V2.md) for the release summary.

## Distribution baseline

Use direct distribution outside the Mac App Store for the first release candidate. MacScope depends on broad process inspection, and App Sandbox compatibility has not been demonstrated. This avoids shipping a sandboxed build with materially incomplete process data; it does not authorize weakening other macOS protections.

Before release, create a normal macOS app target in Xcode with:

- A unique bundle identifier
- Marketing version and build number
- App icon assets
- Deployment target macOS 14+
- Hardened Runtime enabled
- A deliberate entitlement set with no unnecessary privileges
- Automatic or manual signing for the selected Apple Developer team

## Direct distribution checklist

1. Create and install a Developer ID Application certificate.
2. Build and archive the Release configuration in Xcode.
3. Export using Direct Distribution / Developer ID.
4. Confirm Hardened Runtime and a secure timestamp are present.
5. Submit the signed artifact to Apple using Xcode or `notarytool`.
6. Review the complete notarization log, including warnings.
7. Staple the notarization ticket to the distributed artifact.
8. Verify signatures and Gatekeeper assessment on a clean account and Mac.
9. Re-run termination, restricted-process, menu-bar, launch, accessibility, and long-duration monitoring tests on the signed build.

Suggested verification commands:

```sh
codesign --verify --deep --strict --verbose=2 MacScope.app
spctl --assess --type execute --verbose=4 MacScope.app
xcrun stapler validate MacScope.app
```

Never place Apple IDs, app-specific passwords, API keys, certificate private keys, or notary credentials in the repository. Store `notarytool` credentials in Keychain or an approved CI secret store.

## Release blockers

- Create the Xcode macOS app target and archive scheme.
- Choose the final bundle identifier and Apple Developer team.
- Review the generated icon and metadata for final publication quality.
- Complete signed-app Instruments Allocations/Leaks and longer Time Profiler runs.
- Reduce and remeasure the observed steady-state CPU overhead.
- Validate direct-distribution entitlements and process visibility on clean Macs.
- Decide whether launch at login belongs in release scope and, if so, implement it with ServiceManagement.

## Gate ownership

Repository automation can build, test, package an ad-hoc app, verify its signature structure, test ZIP integrity, and verify the DMG. It cannot establish public-release trust.

The release owner must separately provide evidence for:

- Developer ID credentials held outside the repository
- Hardened Runtime and final entitlement review
- Successful Apple notarization and stapling
- Gatekeeper launch on a clean Mac and user account
- Hands-on Apple Silicon coverage across supported macOS versions
- VoiceOver and destructive-action review using the signed candidate
- A sustained Instruments run for CPU, allocations, leaks, and memory growth

Do not label an artifact stable until every external gate has evidence attached to the release record.

## Apple references

- [Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [Distribution workflows](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
