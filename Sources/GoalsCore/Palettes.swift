import CoreGraphics
import Foundation

public enum ColorMode: String, CaseIterable, Identifiable {
    case mono, color
    public var id: String { rawValue }
    public var title: String { self == .mono ? "Einfarbig" : "Farbig" }
}

public enum ColorSchemeKind: String, CaseIterable, Identifiable {
    case metall, signal, pastell, nacht, fest, minze, himmel, glut
    case morgenrot, lagune, polarlicht, abendrot
    case eigene

    /// Jede Zielanzeige zeigt ihren eigenen Verlauf.
    public static let perCard: [ColorSchemeKind] = [.metall, .signal, .pastell, .nacht, .fest, .minze, .himmel, .glut]
    /// Ein einziger Verlauf läuft über alle Zielanzeigen zusammen.
    public static let wholeArea: [ColorSchemeKind] = [.morgenrot, .lagune, .polarlicht, .abendrot]

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .metall: return "Metall"
        case .signal: return "Signal"
        case .pastell: return "Pastell"
        case .nacht: return "Nacht"
        case .fest: return "Fest"
        case .minze: return "Minze"
        case .himmel: return "Himmel"
        case .glut: return "Glut"
        case .morgenrot: return "Morgenrot"
        case .lagune: return "Lagune"
        case .polarlicht: return "Polarlicht"
        case .abendrot: return "Abendrot"
        case .eigene: return "Eigene"
        }
    }
}

/// Farbverlauf einer Zielanzeige. `start` und `end` sind Anteile der Zielanzeigenfläche, (0, 0) liegt oben links.
public struct CardGradient: Equatable {
    public var colors: [UInt32]
    public var start: CGPoint
    public var end: CGPoint
    /// Läuft über alle Zielanzeigen zusammen statt über jede einzeln.
    public var spansCards: Bool

    /// Der Winkel zählt wie in CSS: 0 läuft nach oben, 90 nach rechts, 180 nach unten.
    public init(colors: [UInt32], angle: Double, spansCards: Bool = false) {
        let radians = angle * .pi / 180
        let (dx, dy) = (sin(radians), -cos(radians))
        let half = (abs(dx) + abs(dy)) / 2
        self.colors = colors
        start = CGPoint(x: 0.5 - dx * half, y: 0.5 - dy * half)
        end = CGPoint(x: 0.5 + dx * half, y: 0.5 + dy * half)
        self.spansCards = spansCards
    }

    /// Der Ausschnitt, den eine Zielanzeige zeigt, wenn der Verlauf über `bounds` läuft. Alle Zielanzeigen behalten dieselbe Achse.
    public func section(tile: CGRect, bounds: CGRect) -> CardGradient {
        func project(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (bounds.minX + p.x * bounds.width - tile.minX) / tile.width,
                    y: (bounds.minY + p.y * bounds.height - tile.minY) / tile.height)
        }
        var section = self
        section.start = project(start)
        section.end = project(end)
        return section
    }
}

public struct CardPalette: Equatable {
    /// Bei einem Verlauf dessen erste Farbe.
    public var background: UInt32
    public var border: UInt32
    public var title: UInt32
    public var subtitle: UInt32
    public var text: UInt32
    public var gradient: CardGradient?

    public init(background: UInt32, border: UInt32, title: UInt32, subtitle: UInt32, text: UInt32, gradient: CardGradient? = nil) {
        self.background = background
        self.border = border
        self.title = title
        self.subtitle = subtitle
        self.text = text
        self.gradient = gradient
    }

    /// Die Palette, wie sie eine Zielanzeige an dieser Stelle zeigt.
    public func placed(tile: CGRect, bounds: CGRect) -> CardPalette {
        guard let gradient, gradient.spansCards else { return self }
        var placed = self
        placed.gradient = gradient.section(tile: tile, bounds: bounds)
        return placed
    }
}

public enum Palettes {
    /// Bitcoin-Orange auf dunklem Blatt, wie die Uhr.
    public static let mono = CardPalette(background: 0x0C0B0A, border: 0x9E5208, title: 0xF7931A, subtitle: 0xFFCC7A, text: 0xF0E6D4)

    private static func card(_ colors: [UInt32], _ angle: Double, border: UInt32, title: UInt32, subtitle: UInt32, text: UInt32,
                             spansCards: Bool = false) -> CardPalette {
        CardPalette(background: colors[0], border: border, title: title, subtitle: subtitle, text: text,
                    gradient: CardGradient(colors: colors, angle: angle, spansCards: spansCards))
    }

    // Gehäuse-Metalle des Leitstands, gebürstet.
    static let metall: [CardPalette] = [
        card([0x241806, 0x0E0E0E, 0x2A1C0B], 135, border: 0x9E5208, title: 0xFFCC7A, subtitle: 0xF7931A, text: 0xF0E6D4),
        card([0x0E0E0E, 0x23282D], 180, border: 0x555D65, title: 0xEEF1F3, subtitle: 0x9EA7AF, text: 0xF0E6D4),
        card([0x2A1610, 0x0E0E0E], 45, border: 0x864A3A, title: 0xF7CFC0, subtitle: 0xD18C76, text: 0xF0E6D4),
        card([0x0E0E0E, 0x16222F, 0x0E0E0E], 90, border: 0x3B5674, title: 0xD6E6F5, subtitle: 0x7FA4C8, text: 0xF0E6D4),
        card([0x1E1407, 0x0E0E0E], 160, border: 0x5C3C17, title: 0xE6BE86, subtitle: 0xBE8A4E, text: 0xF0E6D4),
        card([0x0E0E0E, 0x22211E], 20, border: 0x36342F, title: 0xC9C5BE, subtitle: 0x98948D, text: 0xF0E6D4),
    ]

    static let signal: [CardPalette] = [
        ([0x4FC07A, 0xA7E08B], 135),
        ([0xF2C230, 0xFFE98A], 180),
        ([0xF2692B, 0xFFB45C], 45),
        ([0x6FA8E0, 0xA8E0F0], 90),
        ([0xE0806A, 0xF5B6C8], 160),
        ([0xA58BE0, 0xE0B4F0], 20),
    ].map { (stops: ([UInt32], Double)) in
        card(stops.0, stops.1, border: 0x0C0B0A, title: 0x0C0B0A, subtitle: 0x15130F, text: 0x15130F)
    }

    static let pastell: [CardPalette] = [
        card([0xCECBF6, 0xF1E4FB], 135, border: 0x7F77DD, title: 0x26215C, subtitle: 0x3C3489, text: 0x3C3489),
        card([0x9FE1CB, 0xDDF5D8], 180, border: 0x1D9E75, title: 0x04342C, subtitle: 0x085041, text: 0x085041),
        card([0xF5C4B3, 0xFBE3C8], 45, border: 0xD85A30, title: 0x4A1B0C, subtitle: 0x712B13, text: 0x712B13),
        card([0xFAC775, 0xFDEAB0], 90, border: 0xBA7517, title: 0x412402, subtitle: 0x633806, text: 0x633806),
        card([0xF4C0D1, 0xF9DDF0], 160, border: 0xD4537E, title: 0x4B1528, subtitle: 0x72243E, text: 0x72243E),
        card([0xC0DD97, 0xE6F0B8], 20, border: 0x639922, title: 0x173404, subtitle: 0x27500A, text: 0x27500A),
    ]

    static let nacht: [CardPalette] = [
        card([0x26215C, 0x3A2A78], 135, border: 0x534AB7, title: 0xCECBF6, subtitle: 0xAFA9EC, text: 0xF1EFE8),
        card([0x04342C, 0x084438], 180, border: 0x0F6E56, title: 0x9FE1CB, subtitle: 0x5DCAA5, text: 0xF1EFE8),
        card([0x4A1B0C, 0x6B2A10], 45, border: 0x993C1D, title: 0xF5C4B3, subtitle: 0xF0997B, text: 0xF1EFE8),
        card([0x042C53, 0x0C4478], 90, border: 0x185FA5, title: 0xB5D4F4, subtitle: 0x85B7EB, text: 0xF1EFE8),
        card([0x4B1528, 0x701E3C], 160, border: 0x993556, title: 0xF4C0D1, subtitle: 0xED93B1, text: 0xF1EFE8),
        card([0x173404, 0x234608], 20, border: 0x3B6D11, title: 0xC0DD97, subtitle: 0x97C459, text: 0xF1EFE8),
    ]

    // Fest, Minze, Himmel und die Flächen Morgenrot und Lagune nach den Verläufen von Partiful.
    static let fest: [CardPalette] = [
        ([0xF8C4FF, 0xF0B6E0], 180),
        ([0xC9C4FF, 0xF8C4FF], 135),
        ([0x96C4FF, 0xE6D4FF], 45),
        ([0xFFC4D6, 0xFFD9A8], 90),
        ([0xB8F0E0, 0xF8C4FF], 160),
        ([0xFFD9A8, 0xF8C4FF], 20),
    ].map { (stops: ([UInt32], Double)) in
        card(stops.0, stops.1, border: 0x14091F, title: 0x14091F, subtitle: 0x2E1A44, text: 0x2A1A3A)
    }

    static let minze: [CardPalette] = [
        ([0x85DADC, 0xC0E2E2], 130),
        ([0x7FE0C3, 0xD3F2DC], 180),
        ([0xA5E8B0, 0xE6F5C0], 45),
        ([0x8FD8F0, 0xCBEFEA], 90),
        ([0xB4E4D0, 0xEAF7E0], 160),
        ([0x6FCFC0, 0xA8E0F0], 20),
    ].map { (stops: ([UInt32], Double)) in
        card(stops.0, stops.1, border: 0x2E8F92, title: 0x001666, subtitle: 0x0A2A6E, text: 0x10244F)
    }

    static let himmel: [CardPalette] = [
        ([0x96C4FF, 0xFFFFFF], 180),
        ([0xB8B8FF, 0xF0F4FF], 135),
        ([0x8FD8FF, 0xFFFFFF], 45),
        ([0xC4D4FF, 0xFFFFFF], 90),
        ([0xA8E0F0, 0xF4FBFF], 160),
        ([0xD0C4FF, 0xFFFFFF], 20),
    ].map { (stops: ([UInt32], Double)) in
        card(stops.0, stops.1, border: 0x5B7FC7, title: 0x001666, subtitle: 0x0A2A6E, text: 0x10244F)
    }

    static let glut: [CardPalette] = [
        ([0x3A0B1E, 0x8A1F2C], 135),
        ([0x4A1408, 0x7E2A08], 180),
        ([0x2E0F3A, 0x8A1F5C], 45),
        ([0x5A1010, 0x8A2616], 90),
        ([0x3D1A05, 0x6E3A06], 160),
        ([0x1E0F2E, 0x6A1E4A], 20),
    ].map { (stops: ([UInt32], Double)) in
        card(stops.0, stops.1, border: 0xC2571A, title: 0xFFD9A8, subtitle: 0xFFB27A, text: 0xFBEFE0)
    }

    static let morgenrot = card([0x96C4FF, 0xC9C4FF, 0xF8C4FF, 0xFFC9B0], 120, border: 0x7A6FC0,
                                title: 0x14091F, subtitle: 0x2E1A44, text: 0x2A1A3A, spansCards: true)
    static let lagune = card([0x7FE0C3, 0x85DADC, 0x96C4FF, 0xC9C4FF], 60, border: 0x2E8F92,
                             title: 0x001666, subtitle: 0x0A2A6E, text: 0x10244F, spansCards: true)
    static let polarlicht = card([0x0A2A4A, 0x0B5A5A, 0x2A2A78, 0x4A1A6A], 100, border: 0x2E7F8F,
                                 title: 0xBFF5E6, subtitle: 0x9BE0F0, text: 0xF1EFE8, spansCards: true)
    static let abendrot = card([0x1E1240, 0x5A1A6A, 0x8A1F4A, 0x8F3A12], 75, border: 0xA8472A,
                               title: 0xFFE9D0, subtitle: 0xFFC9A8, text: 0xFBEFE0, spansCards: true)

    public static func palette(index: Int, mode: ColorMode, scheme: ColorSchemeKind, custom: CardColors?) -> CardPalette {
        guard mode == .color else { return mono }
        switch scheme {
        case .metall: return metall[index % metall.count]
        case .signal: return signal[index % signal.count]
        case .pastell: return pastell[index % pastell.count]
        case .nacht: return nacht[index % nacht.count]
        case .fest: return fest[index % fest.count]
        case .minze: return minze[index % minze.count]
        case .himmel: return himmel[index % himmel.count]
        case .glut: return glut[index % glut.count]
        case .morgenrot: return morgenrot
        case .lagune: return lagune
        case .polarlicht: return polarlicht
        case .abendrot: return abendrot
        case .eigene: return customPalette(custom)
        }
    }

    /// Eine Zielanzeige ohne eigene Farben, oder mit ungültigen Angaben, zeigt die Farben der Uhr.
    static func customPalette(_ custom: CardColors?) -> CardPalette {
        guard let custom else { return mono }
        let title = parseHex(custom.title) ?? mono.title
        return CardPalette(background: parseHex(custom.background) ?? mono.background,
                           border: title,
                           title: title,
                           subtitle: title,
                           text: parseHex(custom.text) ?? mono.text)
    }

    public static func parseHex(_ value: String) -> UInt32? {
        var text = value.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 else { return nil }
        return UInt32(text, radix: 16)
    }

    public static func hexString(_ value: UInt32) -> String {
        String(format: "#%06X", value & 0xFFFFFF)
    }
}
