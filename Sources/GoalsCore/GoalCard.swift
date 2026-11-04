import Foundation

/// Eigene Farben einer Karte als Hex-Text, damit `goals.json` von Hand lesbar bleibt.
public struct CardColors: Codable, Equatable {
    public var background: String
    public var title: String
    public var text: String

    public init(background: String, title: String, text: String) {
        self.background = background
        self.title = title
        self.text = text
    }
}

/// Eine Goal-Karte: Überschrift, Unterüberschrift, Erklärung, einzeln abschaltbar.
public struct GoalCard: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var detail: String
    public var isEnabled: Bool
    public var colors: CardColors?

    public init(id: String = UUID().uuidString, title: String = "", subtitle: String = "", detail: String = "",
                isEnabled: Bool = true, colors: CardColors? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.isEnabled = isEnabled
        self.colors = colors
    }

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, detail, colors
        case isEnabled = "enabled"
    }
}

extension GoalCard {
    // Synthetisiertes Decodable ignoriert Standardwerte; von Hand geschriebene Karten dürfen Schlüssel weglassen.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        colors = try c.decodeIfPresent(CardColors.self, forKey: .colors)
    }
}

/// Inhalt von `goals.json`.
public struct GoalFile: Codable, Equatable {
    public var version: Int
    public var cards: [GoalCard]

    public init(version: Int = 1, cards: [GoalCard]) {
        self.version = version
        self.cards = cards
    }
}

extension GoalFile {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        cards = try c.decodeIfPresent([GoalCard].self, forKey: .cards) ?? []

        // Fehlende und doppelte IDs eindeutig machen: Auswahl und Schließen hängen an der ID.
        var seen = Set<String>()
        for i in cards.indices {
            if cards[i].id.isEmpty { cards[i].id = "karte-\(i + 1)" }
            var candidate = cards[i].id
            var n = 2
            while seen.contains(candidate) {
                candidate = "\(cards[i].id)-\(n)"
                n += 1
            }
            cards[i].id = candidate
            seen.insert(candidate)
        }
    }
}
