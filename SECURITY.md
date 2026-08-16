# Security Policy

## Supported versions

Security fixes currently target the latest source revision and newest published test release.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could enable unintended process termination, arbitrary file removal, privilege escalation, sensitive-data disclosure, or unsafe command execution. Use GitHub's private vulnerability reporting feature on this repository. If private reporting is unavailable, contact the repository owner privately through the contact method listed on their GitHub profile.

Include affected versions, reproduction steps, impact, and any suggested mitigation. Do not include real credentials or personal data.

## Security boundaries

- MacScope is not intended to bypass macOS permissions or System Integrity Protection.
- Process termination is blocked for MacScope itself, PID 1, known critical services, and root-owned processes. Every signal revalidates PID and start time.
- Storage removal is limited to an immediate child of the user-selected scan folder and uses macOS Trash.
- Network process attribution invokes Apple's `/usr/bin/nettop` without a shell and parses only its requested counter columns.
- Open-connection inspection invokes `/usr/sbin/lsof` directly without a shell, only after Process Details opens, and enforces a five-second timeout, 1 MiB output ceiling, and 200-result limit. Temporary output files are deleted immediately after parsing.
- Launch arguments are read on demand through `KERN_PROCARGS2`, bounded before display, and filtered for common credential formats. Redaction is defense in depth rather than a guarantee; argument output should be reviewed before sharing.
- Release signing and notarization credentials must remain in Keychain or an approved CI secret store and must never be committed.
