import AmneziaCloakCore
// Amnezia Cloak — macOS menubar client for AmneziaWG tunnels.
// Pure UI layer; all testable logic lives in AmneziaCloakCore.
import Cocoa
import UniformTypeIdentifiers

final class App: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement apps have no menu bar, but AppKit still routes Cmd-X/C/V/A
        // through NSApp.mainMenu's key equivalents. Without an Edit menu, paste
        // into NSAlert text fields silently fails. The menu is never rendered.
        installInvisibleEditMenu()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refreshAsync()
        }
        // First-run check: offer to self-install the privileged helper if it's
        // missing. Async so the menubar icon appears immediately.
        DispatchQueue.main.async { [weak self] in self?.offerSetupIfNeeded() }
    }

    /// If the preflight says something is missing, show a setup prompt on the
    /// main thread. Self-installs the helper if the user agrees; surfaces a
    /// link to the README if `amneziawg-tools` is missing (we can't ship that).
    private func offerSetupIfNeeded() {
        switch installPreflight() {
        case .ok:
            return
        case .helperMissing, .helperNotExecutable:
            let a = NSAlert()
            a.messageText = "Amnezia Cloak needs a privileged helper"
            a.informativeText = """
                To manage AmneziaWG tunnels (install, up/down, delete) \
                the app needs a small helper installed at \(Paths.helper) \
                plus a sudoers entry so the app can call it non-interactively.

                Click Install to set this up now — you'll be prompted for \
                your admin password once.
                """
            a.addButton(withTitle: "Install…")
            a.addButton(withTitle: "Not Now")
            NSApp.activate(ignoringOtherApps: true)
            guard a.runModal() == .alertFirstButtonReturn else { return }
            let result = runHelperSelfInstall()
            let done = NSAlert()
            if result.ok {
                done.messageText = "Helper installed"
                done.informativeText = "Amnezia Cloak is ready."
            } else {
                done.messageText = "Setup failed"
                done.informativeText = result.error
            }
            done.runModal()
        case .awgToolsMissing:
            let a = NSAlert()
            a.messageText = "amneziawg-tools is not installed"
            a.informativeText = """
                The app needs `awg` and `awg-quick` at /usr/local/bin/ to \
                bring tunnels up and down. These are third-party binaries \
                not shipped by Amnezia Cloak.

                Install them from:
                https://github.com/amnezia-vpn/amneziawg-tools
                """
            a.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            a.runModal()
        }
    }

    /// Run the bundled `install-helper.sh` with admin privileges via
    /// AppleScript. AppleScript handles the Keychain-style admin prompt for us.
    private func runHelperSelfInstall() -> InstallResult {
        guard
            let helperSrc = Bundle.main.url(forResource: "awg-helper", withExtension: nil),
            let script = Bundle.main.url(forResource: "install-helper", withExtension: "sh")
        else {
            return InstallResult(ok: false, error: "Bundled installer missing from app Resources.")
        }
        let user = NSUserName()
        // Arg-vector into AppleScript's shell string. User-controlled inputs
        // (helperSrc, script) are bundle URLs we own; user comes from NSUserName()
        // which is OS-controlled. Still, quote defensively.
        let quoted: (String) -> String = { s in
            "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        let cmd = "\(quoted(script.path)) \(quoted(helperSrc.path)) \(quoted(user))"
        let source = """
            do shell script \(quoted(cmd)) with administrator privileges
            """
        var err: NSDictionary?
        let scriptObj = NSAppleScript(source: source)
        let out = scriptObj?.executeAndReturnError(&err)
        if let err = err {
            // user cancelled → -128, other errors have a message
            let code = (err[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -128 { return InstallResult(ok: false, error: "Cancelled.") }
            let msg = (err[NSAppleScript.errorMessage] as? String) ?? "Unknown osascript error (\(code))."
            return InstallResult(ok: false, error: msg)
        }
        let text = out?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text == "ok" { return InstallResult(ok: true, error: "") }
        return InstallResult(ok: false, error: text.isEmpty ? "Installer returned no output." : text)
    }

    private func installInvisibleEditMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(
            withTitle: "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        edit.addItem(
            withTitle: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        edit.addItem(
            withTitle: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        edit.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    /// Gather state off the main thread; apply on main.
    private func refreshAsync() {
        DispatchQueue.global().async { [weak self] in
            let tunnels = listTunnels()
            let activeSet = activeTunnelNames()
            DispatchQueue.main.async { self?.applyState(tunnels: tunnels, active: activeSet) }
        }
    }

    private func refresh() { refreshAsync() }

    private func applyState(tunnels: [Tunnel], active activeSet: Set<String>) {
        let primary = activeSet.sorted().first

        // Menubar icon: bundled MenubarIcon as a template image (alpha → menubar tint).
        // `NSImage(named:)` auto-resolves MenubarIcon@2x/@3x for Retina sharpness.
        // Falls back to an SF Symbol when the resource is missing (loose-binary runs).
        if let btn = status.button {
            let image: NSImage? = {
                if let i = NSImage(named: "menubar-icon") {
                    i.size = NSSize(width: 18, height: 18)
                    i.isTemplate = true
                    return i
                }
                let fallback = NSImage(
                    systemSymbolName: "bolt.horizontal.circle.fill",
                    accessibilityDescription: "Amnezia Cloak"
                )
                fallback?.isTemplate = true
                return fallback
            }()
            btn.image = image
            btn.title = ""
            btn.toolTip = primary.map { "Amnezia Cloak: \($0) active" } ?? "Amnezia Cloak: disconnected"
            btn.appearsDisabled = (primary == nil)
        }

        let menu = NSMenu()
        if tunnels.isEmpty {
            let empty = NSMenuItem(title: "(no tunnels — import below)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for t in tunnels {
            let on = activeSet.contains(t.name)
            let item = NSMenuItem(
                title: (on ? "✓  " : "   ") + t.name,
                action: #selector(toggleTunnel(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = t
            item.submenu = tunnelSubmenu(for: t)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        addAction(menu, "Import .conf file…", "i", #selector(importFile))
        addAction(menu, "Paste vpn:// URL…", "v", #selector(pasteVpnURL))
        addAction(menu, "Show full status", "s", #selector(showStatus))
        menu.addItem(.separator())
        addAction(menu, "About Amnezia Cloak", "", #selector(showAbout))
        addAction(menu, "Quit", "q", #selector(quitApp))
        status.menu = menu
    }

    private func addAction(_ m: NSMenu, _ title: String, _ key: String, _ sel: Selector) {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        m.addItem(i)
    }

    private func tunnelSubmenu(for t: Tunnel) -> NSMenu {
        let sub = NSMenu()
        let edit = NSMenuItem(title: "Edit config…", action: #selector(editTunnel(_:)), keyEquivalent: "")
        edit.target = self
        edit.representedObject = t
        sub.addItem(edit)
        let del = NSMenuItem(title: "Delete", action: #selector(deleteTunnel(_:)), keyEquivalent: "")
        del.target = self
        del.representedObject = t
        sub.addItem(del)
        return sub
    }

    // MARK: — menu actions

    @objc private func toggleTunnel(_ sender: NSMenuItem) {
        guard let t = sender.representedObject as? Tunnel else { return }
        let names = Array(activeTunnelNames())
        DispatchQueue.global().async { [weak self] in
            if names.contains(t.name) {
                _ = sudoHelper(["down", t.name])
            } else {
                for other in names { _ = sudoHelper(["down", other]) }
                _ = sudoHelper(["up", t.name])
            }
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    @objc private func importFile() {
        let panel = NSOpenPanel()
        if let confUTI = UTType(filenameExtension: "conf") {
            panel.allowedContentTypes = [confUTI]
        }
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let rawName = url.deletingPathExtension().lastPathComponent
        guard let name = validatedTunnelName(rawName) else {
            alert("Tunnel name must match [A-Za-z0-9_-]{1,15}. Got: \(rawName)")
            return
        }
        guard let conf = try? String(contentsOf: url, encoding: .utf8) else {
            alert("Could not read file.")
            return
        }
        DispatchQueue.global().async { [weak self] in
            let r = installConf(conf, named: name)
            DispatchQueue.main.async {
                self?.alert(r.ok ? "Imported tunnel: \(name)" : "Install failed.\n\n\(r.error)")
                self?.refresh()
            }
        }
    }

    @objc private func pasteVpnURL() {
        let a = NSAlert()
        a.messageText = "Paste vpn:// URL"
        a.informativeText = "Paste the Amnezia connection key (starts with vpn://)"
        a.addButton(withTitle: "Import")
        a.addButton(withTitle: "Cancel")

        // NSTextField is single-line; a 900+ char base64url URL gets clipped so
        // the user only sees the tail. Use a wrapping NSTextView inside a
        // scroll view so the whole URL is visible at paste time.
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 120))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let input = NSTextView(frame: scroll.bounds)
        input.isEditable = true
        input.isRichText = false
        input.font = NSFont(name: "Menlo", size: 11) ?? NSFont.userFixedPitchFont(ofSize: 11)
        input.textContainer?.widthTracksTextView = true
        input.textContainer?.containerSize = NSSize(
            width: scroll.frame.width,
            height: .greatestFiniteMagnitude
        )
        input.isAutomaticDataDetectionEnabled = false
        input.isAutomaticLinkDetectionEnabled = false
        input.isAutomaticQuoteSubstitutionEnabled = false
        input.isAutomaticDashSubstitutionEnabled = false
        input.isAutomaticTextReplacementEnabled = false
        input.isAutomaticSpellingCorrectionEnabled = false
        scroll.documentView = input
        a.accessoryView = scroll

        NSApp.activate(ignoringOtherApps: true)
        // Focus the text view so Cmd-V lands without an extra click.
        DispatchQueue.main.async { a.window.makeFirstResponder(input) }
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let url = input.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard url.hasPrefix("vpn://") else { alert("Not a vpn:// URL."); return }
        DispatchQueue.global().async { [weak self] in
            guard let parsed = VPNURL.parse(url) else {
                DispatchQueue.main.async { self?.alert("Could not decode vpn:// URL (wrong format or not AmneziaWG).") }
                return
            }
            guard parsed.conf.contains("[Interface]") else {
                DispatchQueue.main.async { self?.alert("Invalid conf inside URL.") }
                return
            }
            guard let name = validatedTunnelName(parsed.name) else {
                DispatchQueue.main.async { self?.alert("Decoded tunnel name invalid: \(parsed.name)") }
                return
            }
            let r = installConf(parsed.conf, named: name)
            DispatchQueue.main.async {
                self?.alert(r.ok ? "Imported tunnel: \(name)" : "Install failed.\n\n\(r.error)")
                self?.refresh()
            }
        }
    }

    @objc private func editTunnel(_ sender: NSMenuItem) {
        guard let t = sender.representedObject as? Tunnel else { return }
        let content = readConfViaSudo(t.path)
        let current =
            content.isEmpty
            ? (try? String(contentsOfFile: t.path, encoding: .utf8)) ?? ""
            : content

        let a = NSAlert()
        a.messageText = "Edit \(t.name)"
        a.informativeText = "Saves via sudo. Tunnel must be restarted to apply."
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 340))
        let tv = NSTextView(frame: scroll.bounds)
        tv.isEditable = true
        tv.font = NSFont(name: "Menlo", size: 11) ?? NSFont.userFixedPitchFont(ofSize: 11)
        tv.string = current
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        a.accessoryView = scroll
        a.addButton(withTitle: "Save")
        a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let r = installConf(tv.string, named: t.name)
        alert(r.ok ? "Saved \(t.name).conf. Restart tunnel to apply changes." : "Save failed.\n\n\(r.error)")
    }

    @objc private func deleteTunnel(_ sender: NSMenuItem) {
        guard let t = sender.representedObject as? Tunnel else { return }
        let confirm = NSAlert()
        confirm.messageText = "Delete \(t.name)?"
        confirm.informativeText = "Removes \(t.path). Tunnel must not be active."
        confirm.addButton(withTitle: "Delete")
        confirm.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        if activeTunnelNames().contains(t.name) { _ = sudoHelper(["down", t.name]) }
        _ = sudoHelper(["delete", t.name])
        refresh()
    }

    @objc private func showStatus() {
        let out = bash("\(Paths.awg) show 2>&1")
        let a = NSAlert()
        a.messageText = "Amnezia Cloak Status"
        a.informativeText = out.isEmpty ? "No active tunnels." : out
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        // Build a credits block with a clickable repo link. NSApplication's
        // standard panel auto-populates app name + version from Info.plist
        // (CFBundleName / CFBundleShortVersionString / CFBundleVersion) and
        // the icon from CFBundleIconFile — we just supply the extras.
        let blurb = "Minimal macOS menubar client for AmneziaWG tunnels.\n\n"
        let credits = NSMutableAttributedString(
            string: blurb,
            attributes: [.foregroundColor: NSColor.labelColor]
        )
        let linkText = "github.com/maloyan/amnezia-cloak"
        let link = NSMutableAttributedString(string: linkText)
        if let url = URL(string: "https://github.com/maloyan/amnezia-cloak") {
            link.addAttribute(.link, value: url, range: NSRange(location: 0, length: link.length))
        }
        credits.append(link)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func quitApp() { NSApplication.shared.terminate(nil) }

    private func alert(_ msg: String) {
        let a = NSAlert()
        a.messageText = msg
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
