import AppKit
import GoalsCore

/// `Goals --selftest`: prüft den echten Ablauf im echten Fenster, mit kurzen Zeiten und einer Wegwerf-Datei.
/// Die Karten erscheinen dabei rund 15 Sekunden lang mehrfach auf dem Bildschirm.
@MainActor
enum SelfTest {
    private static var checks: [String: Bool] = [:]

    private static func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private static func spin(until condition: () -> Bool, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while !condition(), Date() < end { spin(0.05) }
        return condition()
    }

    private static func windowInfo(_ panel: NSPanel) -> [String: Any]? {
        let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.first { ($0[kCGWindowNumber as String] as? Int) == panel.windowNumber }
    }

    /// Schickt einen Mausklick direkt an das Fenster, denn Klicks von außen brauchen Bedienungshilfen-Rechte.
    private static func click(_ panel: NSPanel, canvasHeight: CGFloat, at rect: CGRect) {
        let point = NSPoint(x: rect.midX, y: canvasHeight - rect.midY)
        guard let event = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                             windowNumber: panel.windowNumber, context: nil, eventNumber: 0,
                                             clickCount: 1, pressure: 1) else { return }
        panel.sendEvent(event)
    }

    private static func json(_ titles: [String]) -> String {
        let cards = titles.map { "{\"title\":\"\($0)\"}" }.joined(separator: ",")
        return "{\"cards\":[\(cards)]}"
    }

    /// `Goals --show-for <sekunden> [--allow-capture]`: zeigt Beispielkarten und nennt ihr Rechteck auf dem Bildschirm.
    /// Damit lässt sich von außen prüfen, ob eine Aufzeichnung sie erfasst.
    static func show(seconds: TimeInterval, allowCapture: Bool) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("goals-show-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("goals.json")
        try? json(["Prüfkarte A", "Prüfkarte B"]).write(to: url, atomically: true, encoding: .utf8)
        let suite = "goals-show-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let engine = GoalsEngine(store: GoalStore(fileURL: url), settings: GoalSettings(defaults: defaults),
                                 timing: .init(interval: { _ in 3600 }, display: { _ in seconds }))
        engine.start()
        engine.showNow()
        let panel = engine.overlay.panel
        if allowCapture { panel.sharingType = .readOnly }
        spin(0.5)
        let top = (NSScreen.screens.first?.frame.maxY ?? 0) - panel.frame.maxY
        print("\(Int(panel.frame.minX)),\(Int(top)),\(Int(panel.frame.width)),\(Int(panel.frame.height))")
        fflush(stdout)
        spin(seconds)
        return 0
    }

    static func run() -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()

        let frontBefore = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let realBefore = try? Data(contentsOf: GoalStore.defaultFileURL)

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("goals-selftest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("goals.json")
        try? json(["Selbsttest A", "Selbsttest B", "Selbsttest C"]).write(to: url, atomically: true, encoding: .utf8)

        let suite = "goals-selftest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GoalStore(fileURL: url)
        let settings = GoalSettings(defaults: defaults)
        settings.size = .small
        var display: TimeInterval = 1.2
        var interval: TimeInterval = 1.0
        let engine = GoalsEngine(store: store, settings: settings, timing: .init(
            interval: { _ in interval },
            display: { _ in display }))
        let overlay = engine.overlay
        let panel = overlay.panel

        // Takt und Anzeigedauer
        engine.start()
        spin(0.6)
        checks["notBeforeInterval"] = !overlay.isShown
        checks["appearsAfterInterval"] = spin(until: { overlay.isShown }, timeout: 1.5)
        let appeared = Date()
        checks["allCardsTogether"] = engine.scheduler.visibleIDs.count == 3 && overlay.model.placedVisibleCount == 3
        spin(0.3)

        // Fenster im echten Fensterdienst
        let info = windowInfo(panel)
        checks["layerAboveFloating"] = (info?[kCGWindowLayer as String] as? Int ?? 0) >= Int(CGWindowLevelForKey(.statusWindow))
        checks["sharingBlocked"] = (info?[kCGWindowSharingState as String] as? Int) == 0
        let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        checks["listedOnCurrentSpace"] = onScreen.contains { ($0[kCGWindowNumber as String] as? Int) == panel.windowNumber }
        checks["statusSymbolExists"] = NSImage(systemSymbolName: AppDelegate.statusSymbol, accessibilityDescription: nil) != nil
        checks["panelFlags"] = panel.collectionBehavior.contains(.canJoinAllSpaces)
            && panel.collectionBehavior.contains(.fullScreenAuxiliary)
            && panel.styleMask.contains(.nonactivatingPanel)
            && !panel.canBecomeKey && panel.sharingType == .none

        // Mitte des Hauptbildschirms
        if let screen = NSScreen.screens.first?.visibleFrame {
            checks["centeredOnMainScreen"] = abs(panel.frame.midX - screen.midX) < 1 && abs(panel.frame.midY - screen.midY) < 1
        }

        let vanished = spin(until: { !overlay.isShown }, timeout: 3)
        let gone = Date()
        checks["vanishesAfterDisplay"] = vanished && abs(gone.timeIntervalSince(appeared) - 1.2) < 0.5
        if case .waiting(let until) = engine.scheduler.phase {
            checks["nextCountsFromVanish"] = abs(until.timeIntervalSince(gone) - 1.0) < 0.4
        } else {
            checks["nextCountsFromVanish"] = false
        }

        // Schließen per Klick; lange Zeiten, damit nichts von selbst verschwindet
        display = 60
        interval = 60
        settings.onChange?()
        engine.showNow()
        spin(0.4)
        let before = overlay.model.layout
        if let layout = before, let first = layout.placements.first {
            click(panel, canvasHeight: layout.canvas.height, at: first.closeRect)
            spin(0.3)
            checks["closeOneByClick"] = engine.scheduler.visibleIDs.count == 2 && overlay.isShown
            checks["noReflowAfterClose"] = overlay.model.layout == before
            if let all = layout.closeAllRect { click(panel, canvasHeight: layout.canvas.height, at: all) }
            spin(0.4)
            checks["closeAllByClick"] = engine.scheduler.visibleIDs.isEmpty && !overlay.isShown
        } else {
            checks["closeOneByClick"] = false
        }

        // Eine einzelne Karte und alle vier Breiten; die Größe ändert sich im laufenden Betrieb
        let ids = store.cards.map(\.id)
        store.setEnabled(ids[1], false)
        store.setEnabled(ids[2], false)
        engine.showNow()
        spin(0.3)
        checks["singleCardAlone"] = overlay.model.layout?.placements.count == 1 && overlay.model.layout?.closeAllRect == nil
        var widths = true
        for size in CardSize.allCases {
            settings.size = size
            spin(0.2)
            let expected = size.width + 2 * CardLayout.margin
            let bounds = windowInfo(panel)?[kCGWindowBounds as String] as? [String: Any]
            let reported = (bounds?["Width"] as? CGFloat) ?? (bounds?["Width"] as? Double).map { CGFloat($0) } ?? 0
            widths = widths && panel.frame.width == expected && reported == expected && overlay.model.layout?.size == size
        }
        checks["fourWidths"] = widths
        settings.size = .small
        store.setEnabled(ids[1], true)
        store.setEnabled(ids[2], true)
        store.flush()

        // Position: verschieben, wiederherstellen, zurücksetzen
        engine.closeAll()
        spin(0.4)
        settings.positionOffset = CGSize(width: 120, height: -80)
        overlay.invalidateLayout()
        engine.showNow()
        spin(0.3)
        if let screen = NSScreen.screens.first?.visibleFrame {
            checks["positionRestored"] = abs(panel.frame.midX - (screen.midX + 120)) < 1 && abs(panel.frame.midY - (screen.midY - 80)) < 1
            engine.resetPosition()
            spin(0.1)
            checks["positionResetCenters"] = abs(panel.frame.midX - screen.midX) < 1 && abs(panel.frame.midY - screen.midY) < 1
        }

        // Sperre: blendet aus, zeigt nichts, ein fälliger Termin kommt beim Entsperren
        display = 60
        interval = 0.3
        settings.onChange?()
        engine.closeAll()
        spin(0.1)
        engine.suspend(.locked)
        engine.showNow()
        spin(0.6)
        checks["lockedShowsNothing"] = !overlay.isShown
        engine.resume(.locked)
        spin(0.3)
        checks["unlockShowsOverdue"] = overlay.isShown
        interval = 60
        settings.onChange?()
        engine.closeAll()
        spin(0.4)

        // Datei von außen: atomar ersetzen, dann in derselben Datei schreiben
        let replacement = dir.appendingPathComponent("neu.json")
        try? json(["Von aussen ersetzt"]).write(to: replacement, atomically: false, encoding: .utf8)
        rename(replacement.path, url.path)
        checks["externalReplace"] = spin(until: { store.cards.first?.title == "Von aussen ersetzt" }, timeout: 3)
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.truncate(atOffset: 0)
            try? handle.write(contentsOf: Data(json(["Von aussen geschrieben"]).utf8))
            try? handle.close()
        }
        checks["externalInPlace"] = spin(until: { store.cards.first?.title == "Von aussen geschrieben" }, timeout: 3)

        // Kaputte Datei: bleibt unangetastet, eine reparierte hebt die Sperre auf
        let broken = "{ kaputt"
        try? broken.write(to: url, atomically: true, encoding: .utf8)
        _ = spin(until: { store.loadError != nil }, timeout: 3)
        if let id = store.cards.first?.id { store.setEnabled(id, false) }
        store.add()
        store.flush()
        spin(0.5)
        checks["brokenFileUntouched"] = store.loadError != nil && (try? String(contentsOf: url, encoding: .utf8)) == broken
        try? json(["Repariert"]).write(to: url, atomically: true, encoding: .utf8)
        checks["brokenFileRecovers"] = spin(until: { store.loadError == nil && store.cards.first?.title == "Repariert" }, timeout: 3)

        store.stop()

        checks["frontmostUnchanged"] = NSWorkspace.shared.frontmostApplication?.processIdentifier == frontBefore && !app.isActive
        checks["realFileUntouched"] = (try? Data(contentsOf: GoalStore.defaultFileURL)) == realBefore

        let ok = !checks.isEmpty && checks.values.allSatisfy { $0 }
        let lines = checks.keys.sorted().map { "    \"\($0)\": \(checks[$0]! ? "true" : "false")" }.joined(separator: ",\n")
        print("{\n  \"ok\": \(ok),\n  \"checks\": {\n\(lines)\n  }\n}")
        return ok ? 0 : 1
    }
}
