import AppKit
import ServiceManagement

let arguments = CommandLine.arguments

// `Goals --autostart-status` nennt den Stand des Anmeldeobjekts; `sfltool dumpbtm` wartet auf macOS 27 auf eine Admin-Freigabe.
if arguments.contains("--autostart-status") {
    print(SMAppService.mainApp.status == .enabled ? "enabled" : "not enabled (\(SMAppService.mainApp.status.rawValue))")
    exit(0)
}

// Die Prüfmodi laufen ohne `app.run()`. Unter einer schon gelaufenen Bundle-ID ordnet AppKit dann keine Fenster an.
// Der Wert gilt nur für diesen Prozess; der normale Start bleibt unberührt.
if arguments.contains(where: { ["--selftest", "--snapshot", "--show-for"].contains($0) }) {
    UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])
}

// `Goals --selftest` prüft den Ablauf im echten Fenster, `Goals --snapshot <ordner>` rendert Bilder.
if arguments.contains("--selftest") {
    exit(MainActor.assumeIsolated { SelfTest.run() })
}
if let i = arguments.firstIndex(of: "--snapshot"), i + 1 < arguments.count {
    let directory = URL(fileURLWithPath: arguments[i + 1])
    exit(MainActor.assumeIsolated { Snapshot.run(directory: directory) })
}

if let i = arguments.firstIndex(of: "--show-for"), i + 1 < arguments.count, let seconds = TimeInterval(arguments[i + 1]) {
    let allowCapture = arguments.contains("--allow-capture")
    exit(MainActor.assumeIsolated { SelfTest.show(seconds: seconds, allowCapture: allowCapture) })
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    // `NSApplication.delegate` hält nur schwach.
    withExtendedLifetime(delegate) { app.run() }
}
