# Amnezia Cloak

Minimal macOS menubar client for [AmneziaWG](https://github.com/amnezia-vpn/amneziawg-go) tunnels. Lists tunnels in `/etc/amnezia/amneziawg`, toggles them via a tiny privileged helper, imports `.conf` files or `vpn://` share links.

Single-file Swift app (~310 lines), no Xcode project — just `swiftc` + an `Info.plist` + an icon.

## Requirements

- macOS 11+
- [`amneziawg-go`](https://github.com/amnezia-vpn/amneziawg-go) userspace daemon
- [`amneziawg-tools`](https://github.com/amnezia-vpn/amneziawg-tools) (`awg`, `awg-quick`) in `/usr/local/bin`
- `awg-helper` root setuid/sudoers wrapper in `/usr/local/sbin` exposing subcommands: `install <name> <tmpfile>`, `up <name>`, `down <name>`, `delete <name>`, `cat <name>`. Sudoers rule with `NOPASSWD` so the app can call it via `sudo -n`.

## Build

```sh
./build.sh
```

Produces `build/Amnezia Cloak.app` and `Amnezia-Cloak.dmg`.

## Install

Open the DMG, drag `Amnezia Cloak.app` to `/Applications`. Launch from Spotlight.
