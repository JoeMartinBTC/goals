import Foundation

public enum ColorMode: String, CaseIterable, Identifiable {
    case mono, color
    public var id: String { rawValue }
    public var title: String { self == .mono ? "Einfarbig" : "Farbig" }
}

public enum ColorSchemeKind: String, CaseIterable, Identifiable {
    case metall, signal, pastell, nacht, eigene
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .metall: return "Metall"
        case .signal: return "Signal"
        case .pastell: return "Pastell"
        case .nacht: return "Nacht"
        case .eigene: return "Eigene"
        }
    }
}

public struct CardPalette: Equatable {
    public var background: UInt32
    public var border: UInt32
    public var title: UInt32
    public var subtitle: UInt32
    public var text: UInt32

    public init(background: UInt32, border: UInt32, title: UInt32, subtitle: UInt32, text: UInt32) {
        self.background = background
        self.border = border
        self.title = title
        self.subtitle = subtitle
        self.text = text
    }
}

public enum Palettes {
    /// Bitcoin-Orange auf dunklem Blatt, wie die Uhr.
    public static let mono = CardPalette(background: 0x0C0B0A, border: 0x9E5208, title: 0xF7931A, subtitle: 0xFFCC7A, text: 0xF0E6D4)

    // Gehäuse-Metalle des Leitstands.
    static let metall: [CardPalette] = [
        CardPalette(background: 0x0E0E0E, border: 0x9E5208, title: 0xFFCC7A, subtitle: 0xF7931A, text: 0xF0E6D4),
        CardPalette(background: 0x0E0E0E, border: 0x555D65, title: 0xEEF1F3, subtitle: 0x9EA7AF, text: 0xF0E6D4),
        CardPalette(background: 0x0E0E0E, border: 0x864A3A, title: 0xF7CFC0, subtitle: 0xD18C76, text: 0xF0E6D4),
        CardPalette(background: 0x0E0E0E, border: 0x3B5674, title: 0xD6E6F5, subtitle: 0x7FA4C8, text: 0xF0E6D4),
        CardPalette(background: 0x0E0E0E, border: 0x5C3C17, title: 0xE6BE86, subtitle: 0xA9743B, text: 0xF0E6D4),
        CardPalette(background: 0x0E0E0E, border: 0x36342F, title: 0xC9C5BE, subtitle: 0x8F8B84, text: 0xF0E6D4),
    ]

    static let signal: [CardPalette] = [0x5FB37A, 0xE6C44F, 0xF2692B, 0x7FA4C8, 0xD18C76, 0xB39DDB].map {
        CardPalette(background: $0, border: 0x0C0B0A, title: 0x0C0B0A, subtitle: 0x15130F, text: 0x15130F)
    }

    static let pastell: [CardPalette] = [
        CardPalette(background: 0xCECBF6, border: 0x7F77DD, title: 0x26215C, subtitle: 0x3C3489, text: 0x3C3489),
        CardPalette(background: 0x9FE1CB, border: 0x1D9E75, title: 0x04342C, subtitle: 0x085041, text: 0x085041),
        CardPalette(background: 0xF5C4B3, border: 0xD85A30, title: 0x4A1B0C, subtitle: 0x712B13, text: 0x712B13),
        CardPalette(background: 0xFAC775, border: 0xBA7517, title: 0x412402, subtitle: 0x633806, text: 0x633806),
        CardPalette(background: 0xF4C0D1, border: 0xD4537E, title: 0x4B1528, subtitle: 0x72243E, text: 0x72243E),
        CardPalette(background: 0xC0DD97, border: 0x639922, title: 0x173404, subtitle: 0x27500A, text: 0x27500A),
    ]

    static let nacht: [CardPalette] = [
        CardPalette(background: 0x26215C, border: 0x534AB7, title: 0xCECBF6, subtitle: 0xAFA9EC, text: 0xF1EFE8),
        CardPalette(background: 0x04342C, border: 0x0F6E56, title: 0x9FE1CB, subtitle: 0x5DCAA5, text: 0xF1EFE8),
        CardPalette(background: 0x4A1B0C, border: 0x993C1D, title: 0xF5C4B3, subtitle: 0xF0997B, text: 0xF1EFE8),
        CardPalette(background: 0x042C53, border: 0x185FA5, title: 0xB5D4F4, subtitle: 0x85B7EB, text: 0xF1EFE8),
        CardPalette(background: 0x4B1528, border: 0x993556, title: 0xF4C0D1, subtitle: 0xED93B1, text: 0xF1EFE8),
        CardPalette(background: 0x173404, border: 0x3B6D11, title: 0xC0DD97, subtitle: 0x97C459, text: 0xF1EFE8),
    ]

    public static func palette(index: Int, mode: ColorMode, scheme: ColorSchemeKind, custom: CardColors?) -> CardPalette {
        guard mode == .color else { return mono }
        switch scheme {
        case .metall: return metall[index % metall.count]
        case .signal: return signal[index % signal.count]
        case .pastell: return pastell[index % pastell.count]
        case .nacht: return nacht[index % nacht.count]
        case .eigene: return customPalette(custom)
        }
    }

    /// Eine Karte ohne eigene Farben, oder mit ungültigen Angaben, zeigt die Farben der Uhr.
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
