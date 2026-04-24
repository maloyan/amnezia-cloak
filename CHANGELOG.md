# Changelog

All notable changes to this project will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
