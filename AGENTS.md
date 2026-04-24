# AGENTS.md

Guide for autonomous agents (and new humans) working in this repo. Read this before touching code.

---

## What this is

A macOS menubar client for [AmneziaWG](https://github.com/amnezia-vpn/amneziawg-go) tunnels.
~350 lines of Swift. No Xcode project — pure Swift Package Manager.

---

## TL;DR

```sh
swift test          # unit tests (no helper required)
swift build         # compile library + executable
./build.sh          # produce build/Amnezia Cloak.app + Amnezia-Cloak.dmg
```

No env vars. No secrets. No external services needed for tests.

---

## Layout

```
Package.swift
Sources/
  AmneziaCloakCore/              # pure library — testable, no AppKit
    Paths.swift                  # filesystem + binary constants
    Shell.swift                  # Process wrappers (shell, bash, sudoHelper)
    TunnelName.swift             # validatedTunnelName (mirrors helper regex)
    VPNURL.swift                 # pure-Swift vpn:// decoder (Compression framework)
    Tunnel.swift                 # listTunnels, activeTunnelNames
    Installer.swift              # installConf (tmp + helper), readConfViaSudo
  AmneziaCloakApp/               # executable — Cocoa menubar UI, imports Core
    main.swift
Tests/
  AmneziaCloakCoreTests/         # XCTest suite
    TunnelNameTests.swift
    VPNURLTests.swift            # fixture-based vpn:// decode tests
Info.plist                       # bundled into .app by build.sh
assets/
  app-icon.icns                  # dock/Finder icon (bundled as AppIcon.icns)
  app-icon.png                   # 512×512 README hero
  menubar-icon.png               # menubar icon (+ @2x / @3x)
build.sh                         # SPM build → .app bundle → DMG
.github/workflows/               # ci.yml (test + lint + bundle), release.yml (tag → release)
.swiftlint.yml                   # SwiftLint config (strict mode in CI)
.swift-format                    # Apple swift-format config (strict mode in CI)
```

---

## Commands you will actually run

| Task | Command |
|---|---|
| Run tests | `swift test --parallel` |
| Lint (matches CI) | `swiftlint --strict` |
| Format check (matches CI) | `swift-format lint --recursive --strict Sources Tests` |
| Auto-format | `swift-format format --in-place --recursive Sources Tests` |
| Debug build | `swift build` |
| Release bundle + DMG | `./build.sh` |
| Install to /Applications | `./build.sh && sudo rm -rf "/Applications/Amnezia Cloak.app" && cp -R "build/Amnezia Cloak.app" /Applications/` |

Install both linters once: `brew install swiftlint swift-format`.

---

## Architectural rules

1. **Core is UI-free.** `AmneziaCloakCore` must not import `Cocoa` / `AppKit` / `SwiftUI`. Anything touching `NSStatusItem`, `NSAlert`, `NSMenu` belongs in `AmneziaCloakApp`. This is what makes the library testable on a headless CI runner.
2. **Privileged calls go through the helper.** Write-side operations (install / up / down / delete) MUST call `sudoHelper([...])`. The read-side editor reads via `sudo -n /bin/cat <path>` — if you add a new read path, wire it through `readConfViaSudo` or extend the helper. Never interpolate user-controllable strings into `bash(...)`.
3. **Tunnel names are validated twice.** In the app (`validatedTunnelName`) and in the helper (`validate_name`). Both use `^[A-Za-z0-9_-]{1,15}$`. Any drift lets invalid names through one side only to be rejected by the other — keep them in lockstep.
4. **vpn:// parsing has a dual fallback.** The inner protocol object is keyed `"awg"` upstream (lowercased `Proto::Awg` in amnezia-client) but older/third-party exports use `"amnezia-awg"`. `VPNURL.parse` tries `awg` first, then `amnezia-awg`. Do not remove the fallback without evidence that the ecosystem has migrated.
5. **Apple's `COMPRESSION_ZLIB` is raw DEFLATE, not zlib-format.** The vpn:// decoder strips the 4-byte qCompress size prefix, the 2-byte zlib header, and the 4-byte adler32 trailer before feeding the body to `compression_decode_buffer`. See the comment block in `VPNURL.swift`.

---

## Runtime dependencies (installed outside this repo)

The app shells out to the following — they must exist on the user's Mac:

| Path | Purpose | Provided by |
|---|---|---|
| `/usr/local/bin/awg` | status (`awg show`) | [`amneziawg-tools`](https://github.com/amnezia-vpn/amneziawg-tools) |
| `/usr/local/bin/awg-quick` | referenced (not currently invoked) | same |
| `/usr/local/sbin/awg-helper` | privileged `install` / `up` / `down` / `delete` | out-of-band (sudoers `NOPASSWD`) |
| `/usr/bin/sudo`, `/bin/cat`, `/bin/bash`, `/sbin/ifconfig` | system utilities | macOS |
| `/etc/amnezia/amneziawg/*.conf` | tunnel configs (root-owned 600) | written by helper |
| `/var/run/amneziawg/*.name` | runtime pointer `tunnel → utun interface` | managed by `awg-quick` |

`awg-helper` is not shipped here. If you need a reference implementation, see the README of the upstream server-side project that generates these configs.

---

## CI

`.github/workflows/ci.yml` runs on every push and PR to `main`:

- **test** — `swift test --parallel` on `macos-14` with SPM build cache.
- **lint** — `swiftlint --strict` + `swift-format lint --strict`.
- **bundle** — runs `./build.sh`, uploads the DMG as a 14-day artifact.

`.github/workflows/release.yml` runs on `v*` tags: builds the DMG and publishes a GitHub Release with auto-generated notes.

Do not merge a PR with a red CI.

---

## When you change …

| You changed | Things to also change |
|---|---|
| `validatedTunnelName` regex | the helper's `validate_name` check (coordinated release) |
| Helper verbs called from Swift | `README.md` sudoers section + `AGENTS.md` runtime-deps table |
| `Paths.awg` / helper path | the README install instructions |
| `Info.plist` keys | `build.sh` if you add a new resource that needs bundling |
| `main.swift` menubar icon handling | `assets/menubar-icon.png` / `@2x` / `@3x` if the pt size changes |
| vpn:// JSON schema assumptions | `Tests/AmneziaCloakCoreTests/VPNURLTests.swift` fixtures + add a regression test |

---

## Style

- **Indentation**: 4 spaces.
- **Line length**: 120 preferred, 140 soft, 200 hard (matches `.swiftlint.yml`).
- **Imports**: alphabetical (enforced by `swift-format`).
- **Error handling**: prefer returning `Bool` / `Optional` at API boundaries over throwing when the caller can't meaningfully recover. Always surface subprocess failures (non-zero exit, stderr) — don't swallow to `false`.
- **Comments**: explain *why*, not *what*. The "what" is usually obvious from a well-named function.

---

## Things I've been burned on (reviewer's notes from prior PRs)

- `COMPRESSION_ZLIB` name is misleading — see architectural rule #5.
- `--deep` on `codesign` is deprecated and a no-op for our bundle.
- The app menubar image must have `isTemplate = true` or it will render colored in dark mode.
- `NSImage(named:)` is the right loader for Retina: `NSImage(contentsOf:)` loads a single PNG and the OS won't auto-pick `@2x`/`@3x` variants.
- `compression_decode_buffer` returns `0` silently on malformed input — check for zero before calling `Data(bytes:count:)`.
