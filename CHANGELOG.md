# Changelog

All notable changes to this project will be documented in this file. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); version numbers follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Swift Package Manager layout: `AmneziaCloakCore` library + `AmneziaCloakApp` executable.
- XCTest suite covering `validatedTunnelName` and `VPNURL.parse` (both `awg` and legacy `amnezia-awg` inner keys).
- GitHub Actions CI (test + lint + bundle) and release workflow (tag → DMG upload).
- SwiftLint (`--strict`) and Apple swift-format (`--strict`) configs; linters enforced in CI.
- Dependabot config for GitHub Actions updates.
- Issue templates (bug report, feature request) and PR template.
- `CODEOWNERS`, `AGENTS.md`, `CONTRIBUTING.md`, `LICENSE` (MIT).

### Changed
- Rewrote `vpn://` decoder in pure Swift using Apple's `Compression` framework — no longer shells out to `/usr/bin/python3`.
- `build.sh` now invokes `swift build -c release` and assembles the `.app` bundle + DMG around the SPM output.

### Removed
- `MenubarIcon-source.png` (unused).
- `/usr/bin/python3` runtime dependency.

## [0.2] — 2026-04-24

### Added
- Initial public release.
- Menubar client with tunnel list + toggle, `.conf` import, `vpn://` import, in-app config editor, full status dump.
- Custom app and menubar icons (hooded-figure silhouette, template-rendered for menubar).
- Ad-hoc codesigned DMG distribution.
