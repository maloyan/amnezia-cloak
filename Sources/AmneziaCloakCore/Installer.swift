import Foundation

/// Writes `conf` to a tmp file and hands it to `awg-helper install <name>`.
/// Returns `false` if the tmp write fails OR the helper call fails — the caller
/// should surface this to the user verbatim.
public func installConf(_ conf: String, named: String) -> Bool {
    let tmp = NSTemporaryDirectory() + "awg-\(named)-\(Int(Date().timeIntervalSince1970)).conf"
    do {
        try conf.write(toFile: tmp, atomically: true, encoding: .utf8)
    } catch {
        return false
    }
    return sudoHelper(["install", named, tmp])
}

/// `sudo -n /bin/cat <path>` — used by the editor to read a root-owned (600) conf.
public func readConfViaSudo(_ path: String) -> String {
    let r = shell(Paths.sudo, ["-n", Paths.cat, path])
    return r.code == 0 ? r.out : ""
}
