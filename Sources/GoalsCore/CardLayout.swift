import CoreGraphics

public struct CardPlacement: Equatable, Identifiable {
    public var id: String
    public var frame: CGRect
    public var closeRect: CGRect
}

/// Lage aller Karten im Overlay. Koordinaten: Ursprung oben links, y wächst nach unten.
public struct OverlayLayout: Equatable {
    public var size: CardSize
    public var canvas: CGSize
    public var placements: [CardPlacement]
    public var closeAllRect: CGRect?
    /// Karten, die selbst in der kleinsten Größe nicht mehr auf den Bildschirm passen.
    public var hiddenCount: Int
}

public enum OverlayHit: Equatable {
    case close(String)
    case closeAll
    case card(String)
    case none
}

/// Automatisches Raster, Klickziele und Position. Reine Rechnung, damit Klicks ohne Bildschirm prüfbar sind.
public enum CardLayout {
    public static let spacing: CGFloat = 18
    public static let margin: CGFloat = 16
    public static let footerHeight: CGFloat = 48
    public static let closeSize: CGFloat = 34
    public static let closeAllSize = CGSize(width: 160, height: 34)

    /// Bis drei Karten in einer Reihe, danach möglichst quadratisch.
    public static func preferredColumns(_ count: Int) -> Int {
        count <= 3 ? max(count, 1) : Int(Double(count).squareRoot().rounded(.up))
    }

    public static func fit(ids: [String], preferred: CardSize, available: CGSize,
                           height: (String, CardSize) -> CGFloat) -> OverlayLayout {
        let sizes = CardSize.allCases.filter { $0.width <= preferred.width }.sorted { $0.width > $1.width }
        for size in sizes {
            if let layout = arrange(ids: ids, hidden: 0, size: size, available: available, height: height) { return layout }
        }
        // Selbst die kleinste Größe passt nicht: von hinten Karten weglassen und die Zahl nennen.
        let smallest = sizes.last ?? .small
        var count = ids.count - 1
        while count >= 1 {
            if let layout = arrange(ids: Array(ids.prefix(count)), hidden: ids.count - count, size: smallest,
                                    available: available, height: height) { return layout }
            count -= 1
        }
        return placed(ids: Array(ids.prefix(1)), hidden: max(ids.count - 1, 0), columns: 1, size: smallest,
                      available: available, height: height)
    }

    private static func arrange(ids: [String], hidden: Int, size: CardSize, available: CGSize,
                                height: (String, CardSize) -> CGFloat) -> OverlayLayout? {
        guard !ids.isEmpty else {
            return OverlayLayout(size: size, canvas: .zero, placements: [], closeAllRect: nil, hiddenCount: hidden)
        }
        let maxColumns = Int((available.width - 2 * margin + spacing) / (size.width + spacing))
        // Passt nur eine Karte hinein und diese nicht in der Breite, bleibt die kleinste Größe als letzter Halt.
        guard maxColumns >= 1 else { return nil }
        let start = min(preferredColumns(ids.count), maxColumns)
        for columns in start...max(start, maxColumns) {
            let layout = placed(ids: ids, hidden: hidden, columns: columns, size: size, available: available, height: height)
            if layout.canvas.height <= available.height, layout.canvas.width <= available.width { return layout }
        }
        return nil
    }

    private static func placed(ids: [String], hidden: Int, columns: Int, size: CardSize, available: CGSize,
                               height: (String, CardSize) -> CGFloat) -> OverlayLayout {
        let hasFooter = ids.count >= 2 || hidden > 0
        let maxCardHeight = max(available.height - 2 * margin - (hasFooter ? footerHeight : 0), 80)
        let rows = stride(from: 0, to: ids.count, by: columns).map { Array(ids[$0..<min($0 + columns, ids.count)]) }
        let used = rows.map(\.count).max() ?? 1
        let contentWidth = CGFloat(used) * size.width + CGFloat(used - 1) * spacing

        var placements: [CardPlacement] = []
        var y = margin
        for (index, row) in rows.enumerated() {
            let rowHeight = row.map { min(height($0, size), maxCardHeight) }.max() ?? 0
            let rowWidth = CGFloat(row.count) * size.width + CGFloat(row.count - 1) * spacing
            var x = margin + (contentWidth - rowWidth) / 2
            for id in row {
                let frame = CGRect(x: x, y: y, width: size.width, height: rowHeight)
                let close = CGRect(x: frame.maxX - closeSize - 4, y: frame.minY + 4, width: closeSize, height: closeSize)
                placements.append(CardPlacement(id: id, frame: frame, closeRect: close))
                x += size.width + spacing
            }
            y += rowHeight + (index < rows.count - 1 ? spacing : 0)
        }

        let width = contentWidth + 2 * margin
        var closeAll: CGRect?
        if hasFooter {
            if ids.count >= 2 {
                closeAll = CGRect(x: (width - closeAllSize.width) / 2, y: y + (footerHeight - closeAllSize.height) / 2,
                                  width: closeAllSize.width, height: closeAllSize.height)
            }
            y += footerHeight
        }
        return OverlayLayout(size: size, canvas: CGSize(width: width, height: y + margin), placements: placements,
                             closeAllRect: closeAll, hiddenCount: hidden)
    }

    /// Was unter einem Klick liegt. Eine geschlossene Karte zählt nicht mehr.
    public static func hit(_ point: CGPoint, in layout: OverlayLayout, visible: Set<String>) -> OverlayHit {
        if visible.count >= 2, let all = layout.closeAllRect, all.contains(point) { return .closeAll }
        for placement in layout.placements where visible.contains(placement.id) {
            if placement.closeRect.contains(point) { return .close(placement.id) }
            if placement.frame.contains(point) { return .card(placement.id) }
        }
        return .none
    }

    /// Fensterursprung in Bildschirm-Koordinaten (y nach oben): Mitte plus gemerkter Versatz, immer auf dem Bildschirm.
    public static func origin(canvas: CGSize, screen: CGRect, centerOffset: CGSize) -> CGPoint {
        let x = screen.midX + centerOffset.width - canvas.width / 2
        let y = screen.midY + centerOffset.height - canvas.height / 2
        return CGPoint(x: max(screen.minX, min(x, screen.maxX - canvas.width)),
                       y: max(screen.minY, min(y, screen.maxY - canvas.height)))
    }

    public static func centerOffset(origin: CGPoint, canvas: CGSize, screen: CGRect) -> CGSize {
        CGSize(width: origin.x + canvas.width / 2 - screen.midX, height: origin.y + canvas.height / 2 - screen.midY)
    }
}
