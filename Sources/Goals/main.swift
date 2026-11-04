import AppKit

let arguments = CommandLine.arguments

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
    app.run()
}
