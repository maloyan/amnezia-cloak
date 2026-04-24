# Changelog

All notable changes to this project will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.14] — 2026-04-25

### Fixed
- `amneziawg-go utun` started, but `awg-quick` bailed immediately with `rm -f /var/run/wireguard/…name` — two more missing patches that Amnezia's upstream macOS installer applies on top of the `make install` output:
  - **Race against the daemon-write.** `get_real_interface` checks `/var/run/amneziawg/<tun>.name`, but `amneziawg-go` hasn't finished writing it yet. Insert `sleep 0.3; chmod 444 "$WG_TUN_NAME_FILE"` right after the daemon launch, matching Amnezia's canonical build.
  - **Runtime-dir rename.** Upstream `darwin.bash` cleans up `/var/run/wireguard/` (WireGuard's path), not `/var/run/amneziawg/` (AmneziaWG's). Rewrite both `stat` and `rm` paths.
- CI workflow now asserts all four patch counts (`wg → awg` calls, `/var/run/amneziawg/` references, `/var/run/wireguard/` remnants, `sleep 0.3` insertions) and fails loudly on mismatch so a silent patch skip can't ship again.

## [0.13] — 2026-04-25

### Fixed
- `awg-quick` internally called `wg show` / `wg setconf` / `wg showconf`, which aren't installed anywhere — the binary is named `awg`, not `wg`. Users hit `line 112: wg: command not found` on tunnel up. amneziawg-tools' Makefile copies `wg-quick/darwin.bash` verbatim; the rename from `wg` to `awg` inside the script itself is done by Amnezia's own installer but not the `make install` target. Release workflow now `sed -E 's/\bwg /awg /g'` the bundled `awg-quick` after building, matching Amnezia's canonical installer output (leaves `wg-quick`, `wg(8)` comments, `WG_CONFIG` untouched).

## [0.12] — 2026-04-25

### Fixed
- **Auto-detect version drift on launch and prompt to re-run the installer.** Users who installed v0.10 and then dropped v0.11 into `/Applications` kept hitting `awg-quick: version mismatch: bash 3 detected` because the old v0.10 helper (without the PATH fix) was still at `/usr/local/sbin/awg-helper`. Preflight previously saw "helper exists" and returned `.ok`. Now `install-helper.sh` stamps `/usr/local/libexec/amnezia-cloak/VERSION` with the app version, and preflight reads it back; any mismatch (or missing VERSION file) triggers a setup prompt with an "Update…" button that re-runs the installer.
- Tunnel toggle also treats version drift the same as missing helper — won't let you click a tunnel against a stale helper.

### Added
- `InstallPreflight.needsUpdate(installed, current)` case.
- Upgrade prompt: "Amnezia Cloak is out of date on this Mac" / "Update…" button instead of "Install…" when the issue is version drift rather than a fresh install.

### Changed
- `installPreflight()` now takes `currentAppVersion:` so it can compare against the installed VERSION file. App passes `CFBundleShortVersionString` from its own bundle.
- `install-helper.sh` signature is now `<bundle-resources-dir> <invoking-user> <app-version>`; it writes the app version to `/usr/local/libexec/amnezia-cloak/VERSION` at the end of a successful run.

## [0.11] — 2026-04-25

### Added
- **Bundle bash 5 with the DMG.** macOS ships bash 3.2 at `/bin/bash` (frozen at that version for GPL2-licensing reasons), but `awg-quick`'s `darwin.bash` uses bash 4+ features — fresh Macs failed with `awg-quick: version mismatch: bash 3 detected, when bash 4+ required`. CI now builds bash 5.2.37 from source on `macos-14` (`configure --disable-nls --without-bash-malloc && make`), and `install-helper.sh` drops it at `/usr/local/libexec/amnezia-cloak/bash` — private path, won't clash with Homebrew's `/opt/homebrew/bin/bash`.
- `awg-helper` prepends `/usr/local/libexec/amnezia-cloak` to `PATH` before invoking `awg-quick`, so `#!/usr/bin/env bash` inside `awg-quick` resolves to our build automatically.

## [0.10] — 2026-04-25

### Added
- **DMG now ships with prebuilt `awg`, `awg-quick`, and `amneziawg-go` binaries.** The release workflow clones `amnezia-vpn/amneziawg-tools` and `amnezia-vpn/amneziawg-go`, builds both on `macos-14`, and bundles the outputs under `Amnezia Cloak.app/Contents/Resources/bin/`. First-run setup copies them to `/usr/local/bin/` in the same admin prompt as the helper — zero external install steps for arm64 Macs.
- `install-helper.sh` now takes the bundle Resources dir (not just the helper path) so it can discover and install everything in one pass, strips `com.apple.quarantine` from copied binaries so Gatekeeper doesn't block exec.
- Unified setup prompt: one alert listing everything that will be installed (helper + CLI binaries + sudoers), one admin prompt, done.

### Changed
- `runHelperSelfInstall` passes the `.app`'s `Contents/Resources` directory instead of individual file paths.
- Local dev builds (no prebuilt binaries under `scripts/bin/`) still fall back to the upstream-link prompt when `amneziawg-tools` / `amneziawg-go` are missing — the bundled-binaries path is a release-only feature.

## [0.9] — 2026-04-25

### Fixed
- Clicking a tunnel to toggle it up/down could fail silently — the helper's exit code and stderr were discarded, so missing prerequisites (`awg-quick`, `amneziawg-go`) looked like the app was just ignoring the click. Both `toggleTunnel` and `deleteTunnel` now surface the helper's stderr in an NSAlert.
- Preflight now checks `awg-quick` and `amneziawg-go` in addition to `awg`. Previously we only detected `/usr/local/bin/awg` missing, so a Mac with the CLI but no daemon would pass preflight and then fail at `up` time with no signal.

### Added
- Gate tunnel toggle and delete on the same preflight as first-run setup — if the helper is missing the app re-offers self-install; if `amneziawg-tools` / `amneziawg-go` are missing it surfaces the upstream install links instead of silently failing.

## [0.8] — 2026-04-25

### Fixed
- AppleScript source generated for the first-run helper installer was wrapped in single quotes, which AppleScript doesn't recognise as string delimiters — v0.7 produced `expected given … but found unknown token` and the admin prompt never appeared. Separate the two quoting layers: shell-single-quote each argument, then wrap the whole shell command in an AppleScript double-quoted string literal (with `\` and `"` escaped). Verified the generated source with `osacompile` before shipping.

## [0.7] — 2026-04-25

### Added
- First-run self-install of the privileged helper. On launch, if `/usr/local/sbin/awg-helper` is missing (or not executable), the app shows a single dialog — click "Install…" and macOS prompts for your admin password once. The bundled `install-helper.sh` then copies the helper, writes a `NOPASSWD` sudoers rule at `/etc/sudoers.d/amnezia-cloak` (validated via `visudo -cf` before installing), and seeds `/etc/amnezia/amneziawg`. No Terminal steps needed.
- `scripts/awg-helper` — portable `/bin/bash` helper (no `/opt/homebrew/bin/bash`, no `/usr/bin/python3` dependency) bundled into `Amnezia Cloak.app/Contents/Resources/`.
- `scripts/install-helper.sh` — idempotent installer, safe to re-run on upgrades.

### Changed
- Preflight API is now a typed enum (`helperMissing` / `helperNotExecutable` / `awgToolsMissing` / `ok`) instead of a `String?`, so the UI can act differently per failure mode (self-install vs link-to-upstream).
- README: drop the "install awg-helper manually" prerequisite; only `amneziawg-go` and `amneziawg-tools` are documented as prerequisites now.

## [0.6] — 2026-04-25

### Changed
- Install errors surface the real cause — previously every failure path collapsed to a generic `Install failed.` alert. `sudoHelper` now returns the full `ShellResult`; `installConf` returns a new `InstallResult` with a specific, user-visible error message.
- Added `installPreflight()` that checks `/usr/local/sbin/awg-helper` and `/usr/local/bin/awg` exist + are executable before attempting a privileged call, so users on a freshly-installed Mac see a pointed "helper not installed" message with a link to the README Requirements section instead of a silent failure.
- Sudo-denied stderr (`"a password is required"`) is special-cased with an explicit "NOPASSWD sudoers rule required" hint.

## [0.5] — 2026-04-25

### Added
- About menu item opening the standard macOS About panel — shows app icon, version, copyright, and a clickable repo link.
- `NSHumanReadableCopyright` in `Info.plist` (`© 2026 Narek Maloyan · MIT License`).

### Changed
- `Paste vpn:// URL…` dialog now uses a 520×120 wrapping `NSTextView` instead of a single-line `NSTextField` — a ~950-char URL is fully visible while pasting. Auto-focused so Cmd-V lands directly; all auto-substitution (smart quotes, dashes, link detection, spell correction) disabled so macOS can't mutate the base64url.

### Removed
- CodeQL workflow. For a 350-line Swift app with zero external deps and three narrow input surfaces (all regex-validated or fed through a unit-tested pure-Swift decoder), CodeQL's weekly ~600 billable minutes on macOS runners was not worth what it found. Security posture is carried by the `awg-helper` arg-vector pattern, `validatedTunnelName`, unit-tested `VPNURL.parse`, and `SECURITY.md`.

## [0.4] — 2026-04-25

### Added
- Swift Package Manager layout: `AmneziaCloakCore` library + `AmneziaCloakApp` executable.
- XCTest suite covering `validatedTunnelName` and `VPNURL.parse` (both `awg` and legacy `amnezia-awg` inner keys).
- GitHub Actions CI (test + lint + bundle) and release workflow (tag → DMG upload).
- CodeQL SAST workflow (Swift analysis on push/PR and weekly cron).
- SwiftLint (`--strict`) and Apple swift-format (`--strict`) configs; linters enforced in CI.
- Pre-commit hooks mirroring the CI gates (`.pre-commit-config.yaml`).
- Dependabot config for GitHub Actions updates.
- Issue templates (bug report, feature request) and PR template.
- `CODEOWNERS`, `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE` (MIT).
- `.env.example` documenting the zero-env-var runtime contract.
- Invisible Edit menu so Cmd-X / Cmd-C / Cmd-V / Cmd-A work in NSAlert text fields (LSUIElement apps need an explicit mainMenu for key-equivalent routing).
- 512×512 README hero icon.

### Changed
- Rewrote `vpn://` decoder in pure Swift using Apple's `Compression` framework — no longer shells out to `/usr/bin/python3`.
- `build.sh` now invokes `swift build -c release` and assembles the `.app` bundle + DMG around the SPM output.
- All icon assets moved into `assets/`; repo root contains only docs, SPM files, and `build.sh`.

### Removed
- `MenubarIcon-source.png` (unused).
- `/usr/bin/python3` runtime dependency.

## [0.2] — 2026-04-24

### Added
- Initial public release.
- Menubar client with tunnel list + toggle, `.conf` import, `vpn://` import, in-app config editor, full status dump.
- Custom app and menubar icons (hooded-figure silhouette, template-rendered for menubar).
- Ad-hoc codesigned DMG distribution.
