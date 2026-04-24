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

/// Preflight for the install path. Returns `nil` if everything looks good,
/// otherwise a human-readable reason string to show in an alert. Runs cheap
/// filesystem checks only — no subprocess. Call before trying `installConf`
/// on a freshly-installed machine so users get a specific diagnostic instead
/// of a generic "Install failed."
public func installPreflight() -> String? {
    let fm = FileManager.default
    if !fm.fileExists(atPath: Paths.helper) {
        return """
            The privileged helper is not installed.

            Expected at: \(Paths.helper)

            See: https://github.com/maloyan/amnezia-cloak#requirements
            """
    }
    if !fm.isExecutableFile(atPath: Paths.helper) {
        return "The helper at \(Paths.helper) is not executable."
    }
    if !fm.fileExists(atPath: Paths.awg) {
        return """
            amneziawg-tools is not installed.

            Expected binary: \(Paths.awg)

            See: https://github.com/maloyan/amnezia-cloak#requirements
            """
    }
    return nil
}

/// Writes `conf` to a tmp file and hands it to `awg-helper install <name>`.
/// Returns an `InstallResult` with a specific error message so the UI layer
/// can show the user *why* the install failed instead of a generic alert.
public func installConf(_ conf: String, named: String) -> InstallResult {
    if let preflightError = installPreflight() {
        return InstallResult(ok: false, error: preflightError)
    }
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
