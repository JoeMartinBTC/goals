import Foundation

/// Hält die Karten und gleicht sie mit `goals.json` ab. Nur auf dem Haupt-Thread benutzen.
public final class GoalStore: ObservableObject {
    public let fileURL: URL
    @Published public private(set) var cards: [GoalCard] = []
    /// Gesetzt, solange die Datei nicht lesbar ist. Dann bleibt sie unangetastet und Änderungen sind gesperrt.
    @Published public private(set) var loadError: String?
    public private(set) var wasCreated = false
    public var onChange: (() -> Void)?

    private let watcher = FileWatcher()
    private var pendingSave: DispatchWorkItem?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Goals", isDirectory: true)
            .appendingPathComponent("goals.json")
    }

    public var enabledCards: [GoalCard] { cards.filter(\.isEnabled) }

    public func start() {
        load()
        watcher.start(path: fileURL.path) { [weak self] in self?.reload() }
    }

    public func stop() {
        watcher.stop()
    }

    /// Erster Aufruf: legt die Datei mit einer ausgeschalteten Beispielkarte an, wenn sie fehlt.
    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            wasCreated = true
            cards = [GoalCard(title: "Mein erstes Ziel",
                              subtitle: "Eine Zeile, die sagt, worum es geht",
                              detail: "Hier steht in ein bis zwei Sätzen, warum dieses Ziel zählt und was der nächste Schritt ist.",
                              isEnabled: false)]
            write()
            return
        }
        reload()
    }

    /// Liest die Datei neu. Eine fehlende Datei bekommt den Stand aus dem Speicher zurück.
    public func reload() {
        // Eine noch nicht geschriebene Eingabe gewinnt gegen den Stand auf der Platte.
        guard pendingSave == nil else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            if loadError == nil { write() }
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(GoalFile.self, from: data)
            let hadError = loadError != nil
            loadError = nil
            if file.cards != cards {
                cards = file.cards
                onChange?()
            } else if hadError {
                onChange?()
            }
        } catch {
            loadError = "\(fileURL.lastPathComponent) ist nicht lesbar: \(error.localizedDescription)"
            onChange?()
        }
    }

    @discardableResult
    public func add() -> GoalCard {
        let card = GoalCard(title: "Neue Karte")
        guard loadError == nil else { return card }
        cards.append(card)
        changed()
        return card
    }

    public func update(_ card: GoalCard) {
        guard loadError == nil, let i = cards.firstIndex(where: { $0.id == card.id }), cards[i] != card else { return }
        cards[i] = card
        changed()
    }

    public func setEnabled(_ id: String, _ enabled: Bool) {
        guard loadError == nil, let i = cards.firstIndex(where: { $0.id == id }), cards[i].isEnabled != enabled else { return }
        cards[i].isEnabled = enabled
        changed()
    }

    public func remove(_ id: String) {
        guard loadError == nil else { return }
        cards.removeAll { $0.id == id }
        changed()
    }

    public func move(from source: IndexSet, to destination: Int) {
        guard loadError == nil else { return }
        // Wie `Array.move(fromOffsets:toOffset:)` aus SwiftUI, damit der Kern ohne SwiftUI auskommt.
        let moving = source.map { cards[$0] }
        var rest = cards
        for i in source.sorted(by: >) { rest.remove(at: i) }
        let shift = source.filter { $0 < destination }.count
        rest.insert(contentsOf: moving, at: destination - shift)
        cards = rest
        changed()
    }

    /// Schreibt eine ausstehende Änderung sofort.
    public func flush() {
        guard let work = pendingSave else { return }
        work.cancel()
        pendingSave = nil
        write()
    }

    private func changed() {
        onChange?()
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSave = nil
            self?.write()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func write() {
        guard loadError == nil else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(GoalFile(cards: cards)).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Goals: Speichern fehlgeschlagen: \(error)")
        }
    }
}
