## Summary

Describe what changed and why.

## Safety and privacy

- [ ] No credentials, signing material, personal data, or generated release artifacts are included.
- [ ] Process-control and file-removal changes remain explicit, confirmed, and narrowly scoped.
- [ ] Unsupported metrics remain explicit rather than being fabricated as zero.

## Verification

- [ ] `swift build --disable-sandbox`
- [ ] `swift test --disable-sandbox`
- [ ] Relevant manual macOS behavior was checked.
- [ ] Documentation was updated when user-visible behavior changed.
