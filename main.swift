// Amnezia Cloak.app — end-to-end macOS menubar client for AmneziaWG
// Features: list tunnels, toggle, import .conf, paste vpn:// URL, edit tunnel,
// live rx/tx stats in menu + icon refresh.
import Cocoa
import UniformTypeIdentifiers

let confDir  = "/etc/amnezia/amneziawg"
let awgQuick = "/usr/local/bin/awg-quick"
let awg      = "/usr/local/bin/awg"

// MARK: — shell helpers ------------------------------------------------------

@discardableResult
func shell(_ path: String, _ args: [String]) -> (code: Int32, out: String) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
    let out = Pipe(); p.standardOutput = out; p.standardError = out
    do { try p.run() } catch { return (-1, "") }
    p.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func bash(_ cmd: String) -> String { shell("/bin/bash", ["-c", cmd]).out }

let helper = "/usr/local/sbin/awg-helper"

/// Call awg-helper with given args via `sudo -n`. Arg vector is NEVER concatenated
/// into a shell string → no shell-injection surface. If NOPASSWD is missing, caller
/// sees failure (install the sudoers rule to use the app).
@discardableResult
func sudoHelper(_ args: [String]) -> Bool {
    shell("/usr/bin/sudo", ["-n", helper] + args).code == 0
}

/// `[A-Za-z0-9_-]{1,15}` — matches helper-side validate_name.
func validatedTunnelName(_ s: String) -> String? {
    let x = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return x.range(of: #"^[A-Za-z0-9_-]{1,15}$"#, options: .regularExpression) != nil ? x : nil
}

// MARK: — tunnel model -------------------------------------------------------

struct Tunnel { let name: String; let path: String }

func listTunnels() -> [Tunnel] {
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: confDir) else { return [] }
    return files
        .filter { $0.hasSuffix(".conf") }
        .map { Tunnel(name: String($0.dropLast(5)), path: "\(confDir)/\($0)") }
        .sorted { $0.name < $1.name }
}

func activeTunnelNames() -> Set<String> {
    let running = Set(bash("/sbin/ifconfig -l")
        .split(separator: " ").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty })
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: "/var/run/amneziawg")
    else { return [] }
    var active = Set<String>()
    for n in names where n.hasSuffix(".name") {
        let path = "/var/run/amneziawg/\(n)"
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            let utun = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if running.contains(utun) { active.insert(String(n.dropLast(5))) }
        }
    }
    return active
}

// MARK: — vpn:// URL parser --------------------------------------------------

/// Decode Amnezia vpn:// URL → raw awg .conf text + suggested tunnel name.
/// Format: vpn:// + base64url( qCompress(json) )
/// qCompress = BE uint32 uncompressed_size + zlib stream
func parseVpnURL(_ url: String) -> (name: String, conf: String)? {
    let py = """
import json, zlib, base64, struct, sys
u = sys.argv[1].strip()
if not u.startswith('vpn://'): sys.exit(2)
b = u[6:]
b += '=' * (-len(b) % 4)
raw = base64.urlsafe_b64decode(b)
# strip 4-byte BE uncompressed-size header
data = zlib.decompress(raw[4:])
d = json.loads(data)
container = next((c for c in d.get('containers', []) if c.get('container') == 'amnezia-awg'), None)
if not container: sys.exit(3)
# Upstream Amnezia (amnezia-client) keys the nested protocol object 'awg' — lowercased Proto::Awg enum.
# Older/3rd-party exports may still use 'amnezia-awg'; accept both.
awg = container.get('awg') or container.get('amnezia-awg') or {}
inner = json.loads(awg.get('last_config', '{}'))
conf = inner.get('config', '')
name = d.get('description') or 'imported'
name = ''.join(c for c in name if c.isalnum() or c in '_-')[:15] or 'imported'
print(name); print('---CONF---'); print(conf, end='')
"""
    let r = shell("/usr/bin/python3", ["-c", py, url])
    guard r.code == 0 else { return nil }
    let parts = r.out.components(separatedBy: "\n---CONF---\n")
    guard parts.count == 2 else { return nil }
    return (parts[0].trimmingCharacters(in: .whitespacesAndNewlines), parts[1])
}

// MARK: — actions ------------------------------------------------------------

func installConf(_ conf: String, named: String) -> Bool {
    let tmp = NSTemporaryDirectory() + "awg-\(named)-\(Int(Date().timeIntervalSince1970)).conf"
    do { try conf.write(toFile: tmp, atomically: true, encoding: .utf8) }
    catch { return false }
    return sudoHelper(["install", named, tmp])
}

// MARK: — app delegate -------------------------------------------------------

class App: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in self.refreshAsync() }
    }

    /// Off-main state gathering → back to main for UI updates.
    func refreshAsync() {
        DispatchQueue.global().async {
            let tunnels = listTunnels()
            let activeSet = activeTunnelNames()
            DispatchQueue.main.async { self.applyState(tunnels: tunnels, active: activeSet) }
        }
    }

    func refresh() { refreshAsync() }

    func applyState(tunnels: [Tunnel], active activeSet: Set<String>) {
        let primary = activeSet.sorted().first

        // Menubar: bundled MenubarIcon.png as template image (alpha → menubar tint).
        // Falls back to SF Symbol if resource is missing (loose-binary run).
        if let btn = status.button {
            let img: NSImage? = {
                if let url = Bundle.main.url(forResource: "MenubarIcon", withExtension: "png"),
                   let i = NSImage(contentsOf: url) {
                    // 22pt matches NSStatusBar.system.thickness — icon fills the full menubar slot.
                    i.size = NSSize(width: 22, height: 22)
                    i.isTemplate = true
                    return i
                }
                let fallback = NSImage(systemSymbolName: "bolt.horizontal.circle.fill",
                                       accessibilityDescription: "Amnezia Cloak")
                fallback?.isTemplate = true
                return fallback
            }()
            btn.image = img
            btn.title = ""
            btn.toolTip = primary.map { "Amnezia Cloak: \($0) active" } ?? "Amnezia Cloak: disconnected"
            btn.appearsDisabled = (primary == nil)  // dim when off, bright when on
        }

        let menu = NSMenu()
        if tunnels.isEmpty {
            let empty = NSMenuItem(title: "(no tunnels — import below)", action: nil, keyEquivalent: "")
            empty.isEnabled = false; menu.addItem(empty)
        }
        for t in tunnels {
            let on = activeSet.contains(t.name)
            let item = NSMenuItem(
                title: (on ? "✓  " : "   ") + t.name,
                action: #selector(toggleTunnel(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = t
            item.submenu = tunnelSubmenu(for: t)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        addAction(menu, "Import .conf file…",    "i", #selector(importFile))
        addAction(menu, "Paste vpn:// URL…",     "v", #selector(pasteVpnURL))
        addAction(menu, "Show full status",      "s", #selector(showStatus))
        menu.addItem(.separator())
        addAction(menu, "Quit",                  "q", #selector(quitApp))
        status.menu = menu
    }

    func addAction(_ m: NSMenu, _ title: String, _ key: String, _ sel: Selector) {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key); i.target = self; m.addItem(i)
    }

    func tunnelSubmenu(for t: Tunnel) -> NSMenu {
        let sub = NSMenu()
        let edit = NSMenuItem(title: "Edit config…", action: #selector(editTunnel(_:)), keyEquivalent: "")
        edit.target = self; edit.representedObject = t; sub.addItem(edit)
        let del = NSMenuItem(title: "Delete", action: #selector(deleteTunnel(_:)), keyEquivalent: "")
        del.target = self; del.representedObject = t; sub.addItem(del)
        return sub
    }

    // --- menu actions -----------------------------------------------------

    @objc func toggleTunnel(_ sender: NSMenuItem) {
        guard let t = sender.representedObject as? Tunnel else { return }
        let names = Array(activeTunnelNames())
        DispatchQueue.global().async {
            if names.contains(t.name) {
                _ = sudoHelper(["down", t.name])
            } else {
                for other in names { _ = sudoHelper(["down", other]) }
                _ = sudoHelper(["up", t.name])
            }
            DispatchQueue.main.async { self.refresh() }
        }
    }

    @objc func importFile() {
        let panel = NSOpenPanel()
        if let confUTI = UTType(filenameExtension: "conf") {
            panel.allowedContentTypes = [confUTI]
        }
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let rawName = url.deletingPathExtension().lastPathComponent
        guard let name = validatedTunnelName(rawName) else {
            alert("Tunnel name must match [A-Za-z0-9_-]{1,15}. Got: \(rawName)"); return
        }
        guard let conf = try? String(contentsOf: url, encoding: .utf8) else {
            alert("Could not read file."); return
        }
        DispatchQueue.global().async {
            let ok = installConf(conf, named: name)
            DispatchQueue.main.async {
                self.alert(ok ? "Imported tunnel: \(name)" : "Install failed.")
                self.refresh()
            }
        }
    }

    @objc func pasteVpnURL() {
        let a = NSAlert()
        a.messageText = "Paste vpn:// URL"
        a.informativeText = "Paste the Amnezia connection key (starts with vpn://)"
        a.addButton(withTitle: "Import"); a.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 22))
        a.accessoryView = input
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let url = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard url.hasPrefix("vpn://") else { alert("Not a vpn:// URL."); return }
        DispatchQueue.global().async {
            guard let parsed = parseVpnURL(url) else {
                DispatchQueue.main.async { self.alert("Could not decode vpn:// URL (wrong format or not AmneziaWG).") }
                return
            }
            guard parsed.conf.contains("[Interface]") else {
                DispatchQueue.main.async { self.alert("Invalid conf inside URL.") }
                return
            }
            guard let name = validatedTunnelName(parsed.name) else {
                DispatchQueue.main.async { self.alert("Decoded tunnel name invalid: \(parsed.name)") }
                return
            }
            let ok = installConf(parsed.conf, named: name)
            DispatchQueue.main.async {
                self.alert(ok ? "Imported tunnel: \(name)" : "Install failed.")
                self.refresh()
            }
        }
    }

    @objc func editTunnel(_ sender: NSMenuItem) {
        guard let t = sender.representedObject as? Tunnel else { return }
        // sudo cat via arg vector (no shell) — perms 600 for root
        let r = shell("/usr/bin/sudo", ["-n", "/bin/cat", t.path])
        let content = r.code == 0 ? r.out : ""
        let current = content.isEmpty
            ? (try? String(contentsOfFile: t.path, encoding: .utf8)) ?? ""
            : content

        let a = NSAlert()
        a.messageText = "Edit \(t.name)"
        a.informativeText = "Saves via sudo. Tunnel must be restarted to apply."
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 340))
        let tv = NSTextView(frame: scroll.bounds); tv.isEditable = true
        tv.font = NSFont(name: "Menlo", size: 11)
        tv.string = current
        scroll.documentView = tv; scroll.hasVerticalScroller = true
        a.accessoryView = scroll
        a.addButton(withTitle: "Save"); a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        if installConf(tv.string, named: t.name) {
            alert("Saved \(t.name).conf. Restart tunnel to apply changes.")
        } else {
            alert("Save failed.")
        }
    }

    @objc func deleteTunnel(_ sender: NSMenuItem) {
        guard let t = sender.representedObject as? Tunnel else { return }
        let confirm = NSAlert()
        confirm.messageText = "Delete \(t.name)?"
        confirm.informativeText = "Removes \(t.path). Tunnel must not be active."
        confirm.addButton(withTitle: "Delete"); confirm.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        if activeTunnelNames().contains(t.name) { _ = sudoHelper(["down", t.name]) }
        _ = sudoHelper(["delete", t.name])
        refresh()
    }

    @objc func showStatus() {
        let out = bash("\(awg) show 2>&1")
        let a = NSAlert()
        a.messageText = "Amnezia Cloak Status"
        a.informativeText = out.isEmpty ? "No active tunnels." : out
        NSApp.activate(ignoringOtherApps: true); a.runModal()
    }

    @objc func quitApp() { NSApplication.shared.terminate(nil) }

    func alert(_ msg: String) {
        let a = NSAlert(); a.messageText = msg
        NSApp.activate(ignoringOtherApps: true); a.runModal()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let del = App(); app.delegate = del
app.run()
