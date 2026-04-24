# Changelog

All notable changes to this project will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
