import Foundation

public struct InstallResult {
    public let ok: Bool
    /// Human-readable error detail when `ok == false`. Empty on success.
    public let error: String
    public init(ok: Bool, error: String) {
        self.ok = ok
        self.error = error
    }
}

/// What's missing from the install path, if anything.
public enum InstallPreflight: Equatable {
    case ok
    /// `awg-helper` is not at `/usr/local/sbin/awg-helper`. The app can
    /// self-install this from its bundle — no manual steps needed.
    case helperMissing
    /// `amneziawg-tools` is not at `/usr/local/bin/awg`. The app can't
    /// provide this itself (it's a third-party binary distribution), so
    /// the user needs to install it manually.
    case awgToolsMissing
    /// Helper exists but isn't executable — unusual, surface it directly.
    case helperNotExecutable
    /// Helper + tools exist, but the stamped VERSION file differs from
    /// the app's own version (or is missing entirely). Happens on app
    /// upgrade: the user installed v0.10 and just dropped v0.11 into
    /// /Applications — the new bundled helper/bash/binaries haven't been
    /// copied to their system paths yet, and using the old helper means
    /// old bugs persist. Re-running the installer brings everything up
    /// to the new app version.
    case needsUpdate(installed: String, current: String)
}

/// Cheap filesystem-only preflight. No subprocess, no sudo.
/// `currentAppVersion` should be `CFBundleShortVersionString` from Info.plist;
/// we compare against the VERSION file written by install-helper.sh to detect
/// upgrades.
public func installPreflight(currentAppVersion: String) -> InstallPreflight {
    let fm = FileManager.default
    if !fm.fileExists(atPath: Paths.helper) { return .helperMissing }
    if !fm.isExecutableFile(atPath: Paths.helper) { return .helperNotExecutable }
    // All three CLI pieces are needed: `awg` for status, `awg-quick` to bring
    // the tunnel up/down, and `amneziawg-go` as the userspace daemon
    // `awg-quick` spawns on macOS.
    if !fm.fileExists(atPath: Paths.awg) { return .awgToolsMissing }
    if !fm.fileExists(atPath: Paths.awgQuick) { return .awgToolsMissing }
    if !fm.fileExists(atPath: Paths.amneziawgGo) { return .awgToolsMissing }
    // Version drift: compare stamped VERSION with the running app's version.
    let installedVersion =
        (try? String(contentsOfFile: Paths.libexecVersion, encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if installedVersion != currentAppVersion {
        return .needsUpdate(installed: installedVersion, current: currentAppVersion)
    }
    return .ok
}

/// Writes `conf` to a tmp file and hands it to `awg-helper install <name>`.
/// Returns an `InstallResult` with a specific error message so the UI layer
/// can show the user *why* the install failed instead of a generic alert.
public func installConf(_ conf: String, named: String) -> InstallResult {
    // Don't block on preflight here — the UI layer handles helper-missing by
    // offering to self-install. If preflight is still not OK when we get here,
    // the sudoHelper call will fail with a useful stderr and we'll return that.
    let tmp = NSTemporaryDirectory() + "awg-\(named)-\(Int(Date().timeIntervalSince1970)).conf"
    do {
        try conf.write(toFile: tmp, atomically: true, encoding: .utf8)
    } catch {
        return InstallResult(ok: false, error: "Could not write temp file: \(error.localizedDescription)")
    }
    let result = sudoHelper(["install", named, tmp])
    if result.code == 0 {
        return InstallResult(ok: true, error: "")
    }
    let stderr = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
    let detail = stderr.isEmpty ? "helper exited with code \(result.code)" : stderr
    // Two very common failures deserve pointed explanations.
    if stderr.contains("a password is required") || stderr.contains("sudo:") {
        return InstallResult(
            ok: false,
            error: """
                sudo denied the helper call. A NOPASSWD sudoers rule is required.

                See: https://github.com/maloyan/amnezia-cloak#requirements

                Raw stderr: \(detail)
                """
        )
    }
    return InstallResult(ok: false, error: detail)
}

/// `sudo -n /bin/cat <path>` — used by the editor to read a root-owned (600) conf.
public func readConfViaSudo(_ path: String) -> String {
    let r = shell(Paths.sudo, ["-n", Paths.cat, path])
    return r.code == 0 ? r.out : ""
}
