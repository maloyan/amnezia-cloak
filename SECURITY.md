# Security Policy

## Reporting a vulnerability

Email `narek@forgood.ai`. Do **not** open a public issue or pull request for a suspected vulnerability.

Please include, to the extent you can:

- A brief description of the issue and its impact.
- A proof of concept (conf file, `vpn://` URL, command sequence, etc.).
- Affected versions (commit SHA or release tag).
- Your disclosure timeline preference.

You should receive an acknowledgement within 72 hours. If you don't, follow up on the same thread — do not escalate to public disclosure yet. I'll work with you on a coordinated timeline; the default is a 30-day embargo from the first confirmation, extendable by mutual agreement if a fix is non-trivial.

## Scope

**In scope:**

- Privilege escalation through the app's interaction with `awg-helper` / `sudo -n`.
- Shell-injection surfaces in `Sources/AmneziaCloakCore/Shell.swift`, `Installer.swift`, or any `bash(…)` call site.
- Malformed `vpn://` URLs that cause panics, OOB reads, or incorrect config material to be written to disk.
- Supply-chain attacks via Swift Package Manager dependencies (currently: none — this is a single-package repo with zero third-party deps).
- Misuse of `NSImage`/`NSAlert`/`NSOpenPanel` that exposes local file paths or enables sandbox escape on sandboxed macOS installs.

**Out of scope:**

- Vulnerabilities in `amneziawg-go`, `amneziawg-tools`, or `amnezia-client` — report those upstream.
- Bugs in macOS itself or in third-party tunnel configs.
- DoS via spamming the UI (`NSAlert` loops etc.).
- Issues that require already-privileged local access (`root` / `sudo` without the helper).

## Supported versions

Only the latest released tag is supported. Security fixes ship as a new patch or minor release — I do not backport.
