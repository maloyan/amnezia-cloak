import Foundation

public struct Tunnel: Hashable {
    public let name: String
    public let path: String
    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public func listTunnels() -> [Tunnel] {
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: Paths.confDir) else { return [] }
    return
        files
        .filter { $0.hasSuffix(".conf") }
        .map { Tunnel(name: String($0.dropLast(5)), path: "\(Paths.confDir)/\($0)") }
        .sorted { $0.name < $1.name }
}

/// Returns names of tunnels currently up: a `*.name` pointer exists in the runtime
/// dir AND the referenced `utun` interface is live per `ifconfig -l`.
public func activeTunnelNames() -> Set<String> {
    let running = Set(
        bash("\(Paths.ifconfig) -l")
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    )
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: Paths.runtimeDir) else {
        return []
    }
    var active = Set<String>()
    for n in names where n.hasSuffix(".name") {
        let path = "\(Paths.runtimeDir)/\(n)"
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            let utun = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if running.contains(utun) { active.insert(String(n.dropLast(5))) }
        }
    }
    return active
}
