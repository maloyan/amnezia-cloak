# Contributing to Amnezia Cloak

Thanks for taking the time. This repo is small and opinionated — the rules below keep it that way.

## Before you start

Open an issue first if your change is more than a bug fix or a small nit. A lot of the code here is load-bearing for security (privileged subprocess calls via `sudo -n`, `vpn://` parsing, tunnel-name validation mirrored in a separate helper), so a short design sketch saves you rewriting.

## Setup

```sh
git clone https://github.com/maloyan/amnezia-cloak.git
cd amnezia-cloak
brew install swiftlint swift-format pre-commit
pre-commit install              # runs lint + format on every commit
pre-commit install --hook-type pre-push   # runs tests on push
swift test
```

That's it — no secrets, no env vars. For end-to-end manual testing you also need `amneziawg-tools` and the `awg-helper` sudoers rule on your Mac (see `AGENTS.md` → Runtime dependencies).

## Dev loop

```sh
swift test --parallel                                               # fast
swiftlint --strict                                                  # lint
swift-format lint --recursive --strict Sources Tests                # format
swift-format format --in-place --recursive Sources Tests            # auto-fix
./build.sh                                                          # produce .app + DMG
open "build/Amnezia Cloak.app"                                       # smoke
```

CI runs the same four commands in `.github/workflows/ci.yml`. If they pass locally, CI should pass.

## PR checklist

Use the template. Minimum:

- [ ] Tests added or updated (bug fixes need a regression test)
- [ ] `swift test` green
- [ ] `swiftlint --strict` green
- [ ] `swift-format lint --strict` green
- [ ] `./build.sh` produces a runnable bundle
- [ ] Any new `sudo -n` / `bash(…)` call has a comment explaining why it can't be arg-vectored

## Commit style

- Imperative, present tense. `"Add X"` not `"Added X"` / `"Adds X"`.
- First line ≤ 72 chars, body wraps at 80.
- Body explains *why*, not *what*. The diff says what.
- Don't co-author humans into your commits if you used an AI assistant — author yourself, mention the tool in the PR body if relevant.

## Architectural invariants (don't break these)

See `AGENTS.md` → Architectural rules. The big four:

1. `AmneziaCloakCore` is UI-free.
2. Privileged writes go through `awg-helper`.
3. Tunnel-name regex must stay in lockstep with the helper.
4. `vpn://` decoder must accept both `"awg"` and `"amnezia-awg"` inner keys.

## Reporting security issues

Don't open a public issue. Email `narek@forgood.ai` with details and a proof of concept. If you don't get an acknowledgement within 72 hours, follow up on the email thread — do not disclose publicly.

## License

By contributing you agree your work ships under the MIT license in `LICENSE`.
