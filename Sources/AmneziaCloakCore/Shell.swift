import Foundation

public struct ShellResult {
    public let code: Int32
    public let out: String
    public init(code: Int32, out: String) { self.code = code; self.out = out }
}

/// Run a subprocess with an explicit arg vector. NEVER invokes a shell, so there is
/// no injection surface at this layer. Callers interpolating into `bash("…")` are the
/// only place shell metacharacters can matter; use arg-vector calls whenever possible.
@discardableResult
public func shell(_ path: String, _ args: [String]) -> ShellResult {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let out = Pipe()
    p.standardOutput = out
    p.standardError = out
    do { try p.run() } catch { return ShellResult(code: -1, out: "") }
    p.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return ShellResult(code: p.terminationStatus, out: String(data: data, encoding: .utf8) ?? "")
}

/// Convenience wrapper when you genuinely need a shell (glob/pipe). Prefer `shell()` above.
public func bash(_ cmd: String) -> String {
    shell(Paths.bash, ["-c", cmd]).out
}

/// Call the privileged helper via `sudo -n`. Arg vector is never concatenated into a
/// shell string — no injection surface. Requires a `NOPASSWD` sudoers rule.
@discardableResult
public func sudoHelper(_ args: [String]) -> Bool {
    shell(Paths.sudo, ["-n", Paths.helper] + args).code == 0
}
