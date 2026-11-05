import AppKit
import GoalsCore
import SwiftUI

/// `Goals --snapshot <ordner>`: rendert Zielanzeigen und Einstellungsfenster als PNG, ohne Recht auf Bildschirmaufnahme.
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

    /// Für die Übersichten: sechs Zielanzeigen, denn ab der siebten wiederholen sich die Verläufe.
    private static let galleryCards = demoCards + [
        GoalCard(id: "d", title: "Lernen", subtitle: "Eine Stunde am Tag",
                 detail: "Beispieltext: Was du bis zum Jahresende können willst."),
        GoalCard(id: "e", title: "Freunde", subtitle: "Einmal im Monat treffen",
                 detail: "Beispieltext: Wer dir wichtig ist und wann ihr euch seht."),
        GoalCard(id: "f", title: "Rücklage", subtitle: "Sechs Monatsausgaben",
                 detail: "Beispieltext: Welche Zahl am Monatsende stimmen soll."),
    ]

    /// Für die Projektseite: sechs Ziele von groß bis klein.
    private static let siteCards: [String: [GoalCard]] = [
        "de": [
            GoalCard(id: "a", title: "Lebenswerk", subtitle: "Etwas bauen, das bleibt",
                     detail: "Ein Werk, das in 30 Jahren noch jemandem hilft."),
            GoalCard(id: "b", title: "Freiheit", subtitle: "Mit 55 frei entscheiden",
                     detail: "Jeden Monat geht zuerst ein fester Betrag zur Seite, der Rest danach."),
            GoalCard(id: "c", title: "Gesundheit", subtitle: "Mit 80 noch die Treppe hoch",
                     detail: "Dafür jeden Tag 30 Minuten raus, auch bei Regen."),
            GoalCard(id: "d", title: "Lernen", subtitle: "Bis zum Sommer Spanisch sprechen",
                     detail: "Zwanzig Minuten am Tag, bis ein Gespräch ohne Übersetzer klappt."),
            GoalCard(id: "e", title: "Familie", subtitle: "Sonntags essen ohne Handy",
                     detail: "Alle sitzen am Tisch, und das Telefon bleibt in der Küche."),
            GoalCard(id: "f", title: "Freunde", subtitle: "Einen alten Freund anrufen",
                     detail: "Zehn Minuten reichen. Nicht erst, wenn mal Zeit ist."),
        ],
        "en": [
            GoalCard(id: "a", title: "Life’s work", subtitle: "Build something that lasts",
                     detail: "A piece of work that still helps someone in 30 years."),
            GoalCard(id: "b", title: "Freedom", subtitle: "Free to choose at 55",
                     detail: "Each month a fixed amount goes aside first, then the rest."),
            GoalCard(id: "c", title: "Health", subtitle: "Still taking the stairs at 80",
                     detail: "So 30 minutes outside every day, even in the rain."),
            GoalCard(id: "d", title: "Learning", subtitle: "Speak Spanish by summer",
                     detail: "Twenty minutes a day, until a conversation works without a translator."),
            GoalCard(id: "e", title: "Family", subtitle: "Sunday dinner without phones",
                     detail: "Everyone sits at the table, and the phone stays in the kitchen."),
            GoalCard(id: "f", title: "Friends", subtitle: "Call an old friend",
                     detail: "Ten minutes is enough. Don’t wait until there’s time."),
        ],
    ]

    private static func write(_ image: NSImage?, _ url: URL) -> Bool {
        guard let tiff = image?.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: url)) != nil
    }

    private static func overlayModel(cards: [GoalCard], size: CardSize, mode: ColorMode, scheme: ColorSchemeKind,
                                     available: CGSize = CGSize(width: 3200, height: 1800)) -> OverlayModel {
        let model = OverlayModel()
        var entries: [String: OverlayModel.Entry] = [:]
        for (index, card) in cards.enumerated() {
            entries[card.id] = .init(card: card, palette: Palettes.palette(index: index, mode: mode, scheme: scheme, custom: card.colors))
        }
        model.entries = entries
        model.visible = Set(cards.map(\.id))
        let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        model.layout = CardLayout.fit(ids: cards.map(\.id), preferred: size, available: available) { id, s in
            byID[id].map { CardMeasure.height(of: $0, size: s) } ?? 0
        }
        return model
    }

    private static func cardsImage(size: CardSize, mode: ColorMode, scheme: ColorSchemeKind) -> NSImage? {
        let renderer = ImageRenderer(content: OverlayContentView(model: overlayModel(cards: demoCards, size: size, mode: mode, scheme: scheme)))
        renderer.scale = 1
        return renderer.nsImage
    }

    /// Durchsichtiger Hintergrund und doppelte Auflösung, damit die Zielanzeigen direkt auf der Seite liegen.
    private static func siteImage(cards: [GoalCard], columns: Int, mode: ColorMode, scheme: ColorSchemeKind) -> NSImage? {
        let width = CGFloat(columns) * (CardSize.small.width + CardLayout.spacing) + 2 * CardLayout.margin
        let model = overlayModel(cards: cards, size: .small, mode: mode, scheme: scheme, available: CGSize(width: width, height: 1800))
        let renderer = ImageRenderer(content: OverlayContentView(model: model))
        renderer.scale = 2
        return renderer.nsImage
    }

    /// Bilder der Projektseite: Zielanzeigen je Sprache, das Einstellungsfenster hell und dunkel.
    private static func writeSiteImages(to directory: URL) -> Bool {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var ok = true
        for (language, cards) in siteCards {
            for scheme in [ColorSchemeKind.polarlicht, .morgenrot] {
                ok = write(siteImage(cards: cards, columns: 3, mode: .color, scheme: scheme),
                           directory.appendingPathComponent("hero-\(scheme.rawValue)-\(language).png")) && ok
            }
            for scheme in [ColorSchemeKind.fest, .abendrot, .polarlicht, .morgenrot] {
                ok = write(siteImage(cards: cards, columns: 2, mode: .color, scheme: scheme),
                           directory.appendingPathComponent("karten-\(scheme.rawValue)-\(language).png")) && ok
            }
            ok = write(siteImage(cards: cards, columns: 2, mode: .mono, scheme: .metall),
                       directory.appendingPathComponent("karten-einfarbig-\(language).png")) && ok
        }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("goals-snapshot-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("goals.json")
        if let data = try? JSONEncoder().encode(GoalFile(cards: siteCards["de"] ?? [])) { try? data.write(to: url) }
        let defaults = MemoryDefaults()

        let store = GoalStore(fileURL: url)
        store.load()
        let engine = GoalsEngine(store: store, settings: GoalSettings(defaults: defaults))
        engine.start()   // damit die Statuszeile die nächste Erinnerung nennt
        defer { store.stop() }
        for (name, appearance) in [("hell", NSAppearance.Name.aqua), ("dunkel", NSAppearance.Name.darkAqua)] {
            ok = write(settingsImage(tab: .cards, store: store, settings: engine.settings, engine: engine,
                                     appearance: NSAppearance(named: appearance), scale: 2),
                       directory.appendingPathComponent("einstellungen-\(name).png")) && ok
        }
        return ok
    }

    /// Übersicht für die Doku: je Schema alle Verläufe, in zwei Spalten.
    private static func galleryImage(_ schemes: [ColorSchemeKind]) -> NSImage? {
        func column(_ schemes: ArraySlice<ColorSchemeKind>) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(schemes)) { scheme in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(scheme.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.leading, CardLayout.margin)
                        OverlayContentView(model: overlayModel(cards: galleryCards, size: .small, mode: .color, scheme: scheme))
                    }
                }
            }
        }
        let half = schemes.count / 2
        let renderer = ImageRenderer(content: HStack(alignment: .top, spacing: 16) {
            column(schemes[..<half])
            column(schemes[half...])
        }
        .padding(16)
        .background(Color(hex: 0x5A5A5A)))
        renderer.scale = 1
        return renderer.nsImage
    }

    /// Einstellungsfenster über `cacheDisplay`, denn `ImageRenderer` zeichnet keine nativen Bedienelemente.
    private static func settingsImage(tab: SettingsNavigation.Tab, store: GoalStore, settings: GoalSettings, engine: GoalsEngine,
                                      appearance: NSAppearance? = nil, scale: Int? = nil) -> NSImage? {
        let navigation = SettingsNavigation()
        navigation.tab = tab
        let size = NSSize(width: 880, height: 680)
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -3000, y: -3000), size: size), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.appearance = appearance
        let host = NSHostingView(rootView: SettingsRootView(store: store, settings: settings, engine: engine,
                                                            autoStart: AutoStart(), navigation: navigation))
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        window.orderBack(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        host.layoutSubtreeIfNeeded()
        let scaled = scale.flatMap { NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * $0, pixelsHigh: Int(size.height) * $0,
                                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) }
        scaled?.size = size
        guard let rep = scaled ?? host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
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

        ok = write(galleryImage(ColorSchemeKind.perCard), directory.appendingPathComponent("galerie-je-karte.png")) && ok
        ok = write(galleryImage(ColorSchemeKind.wholeArea), directory.appendingPathComponent("galerie-flaeche.png")) && ok

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("goals-snapshot-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("goals.json")
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(GoalFile(cards: demoCards)) { try? data.write(to: url) }
        let defaults = MemoryDefaults()

        let store = GoalStore(fileURL: url)
        store.load()
        let settings = GoalSettings(defaults: defaults)
        let engine = GoalsEngine(store: store, settings: settings)
        ok = write(settingsImage(tab: .cards, store: store, settings: settings, engine: engine),
                   directory.appendingPathComponent("einstellungen.png")) && ok
        ok = write(settingsImage(tab: .display, store: store, settings: settings, engine: engine),
                   directory.appendingPathComponent("einstellungen-anzeige.png")) && ok
        ok = writeSiteImages(to: directory.appendingPathComponent("seite")) && ok
        print(ok ? directory.path : "Snapshot fehlgeschlagen")
        return ok ? 0 : 1
    }
}
