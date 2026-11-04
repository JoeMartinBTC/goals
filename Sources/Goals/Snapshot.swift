import AppKit
import GoalsCore
import SwiftUI

/// `Goals --snapshot <ordner>`: rendert Karten und Einstellungsfenster als PNG, ohne Recht auf Bildschirmaufnahme.
@MainActor
enum Snapshot {
    private static let demoCards = [
        GoalCard(id: "a", title: "Fokus", subtitle: "Eine Sache zuerst fertig machen",
                 detail: "Beispieltext: Warum dieses Ziel zählt und was der nächste Schritt ist.",
                 colors: CardColors(background: "#101F33", title: "#7FD1FF", text: "#E8F0F7")),
        GoalCard(id: "b", title: "Gesundheit", subtitle: "Jeden Tag 30 Minuten raus",
                 detail: "Beispieltext: Die Erklärung darf ein bis zwei Sätze lang sein und bricht von selbst um.",
                 colors: CardColors(background: "#2B1A33", title: "#F2A9FF", text: "#F5EAF7")),
        GoalCard(id: "c", title: "Projekt", subtitle: "Erster Kunde bis Monatsende",
                 detail: "Beispieltext: Hier steht, woran du den Erfolg erkennst.",
                 colors: CardColors(background: "#1C2B14", title: "#BDEB7A", text: "#EFF7E6")),
    ]

    private static func write(_ image: NSImage?, _ url: URL) -> Bool {
        guard let tiff = image?.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: url)) != nil
    }

    private static func cardsImage(size: CardSize, mode: ColorMode, scheme: ColorSchemeKind) -> NSImage? {
        let model = OverlayModel()
        var entries: [String: OverlayModel.Entry] = [:]
        for (index, card) in demoCards.enumerated() {
            entries[card.id] = .init(card: card, palette: Palettes.palette(index: index, mode: mode, scheme: scheme, custom: card.colors))
        }
        model.entries = entries
        model.visible = Set(demoCards.map(\.id))
        let byID = Dictionary(uniqueKeysWithValues: demoCards.map { ($0.id, $0) })
        model.layout = CardLayout.fit(ids: demoCards.map(\.id), preferred: size, available: CGSize(width: 3200, height: 1800)) { id, s in
            byID[id].map { CardMeasure.height(of: $0, size: s) } ?? 0
        }
        let renderer = ImageRenderer(content: OverlayContentView(model: model))
        renderer.scale = 1
        return renderer.nsImage
    }

    /// Einstellungsfenster über `cacheDisplay`, denn `ImageRenderer` zeichnet keine nativen Bedienelemente.
    private static func settingsImage(tab: SettingsNavigation.Tab, store: GoalStore, settings: GoalSettings, engine: GoalsEngine) -> NSImage? {
        let navigation = SettingsNavigation()
        navigation.tab = tab
        let size = NSSize(width: 880, height: 680)
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -3000, y: -3000), size: size), styleMask: [.titled],
                              backing: .buffered, defer: false)
        let host = NSHostingView(rootView: SettingsRootView(store: store, settings: settings, engine: engine,
                                                            autoStart: AutoStart(), navigation: navigation))
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        window.orderBack(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    static func run(directory: URL) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var ok = true

        for size in CardSize.allCases {
            ok = write(cardsImage(size: size, mode: .mono, scheme: .metall),
                       directory.appendingPathComponent("karten-\(size.rawValue)-einfarbig.png")) && ok
            for scheme in ColorSchemeKind.allCases {
                ok = write(cardsImage(size: size, mode: .color, scheme: scheme),
                           directory.appendingPathComponent("karten-\(size.rawValue)-\(scheme.rawValue).png")) && ok
            }
        }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("goals-snapshot-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("goals.json")
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(GoalFile(cards: demoCards)) { try? data.write(to: url) }
        let suite = "goals-snapshot-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GoalStore(fileURL: url)
        store.load()
        let settings = GoalSettings(defaults: defaults)
        let engine = GoalsEngine(store: store, settings: settings)
        ok = write(settingsImage(tab: .cards, store: store, settings: settings, engine: engine),
                   directory.appendingPathComponent("einstellungen.png")) && ok
        ok = write(settingsImage(tab: .display, store: store, settings: settings, engine: engine),
                   directory.appendingPathComponent("einstellungen-anzeige.png")) && ok
        print(ok ? directory.path : "Snapshot fehlgeschlagen")
        return ok ? 0 : 1
    }
}
