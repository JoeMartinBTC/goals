import AppKit
import GoalsCore
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// Farbe als Hex-Text für `goals.json`.
    var hexText: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let value = UInt32(round(c.redComponent * 255)) << 16 | UInt32(round(c.greenComponent * 255)) << 8
            | UInt32(round(c.blueComponent * 255))
        return Palettes.hexString(value)
    }
}

struct CardMetrics {
    let title, subtitle, detail, padding, spacing, corner, closeIcon: CGFloat
}

extension CardSize {
    var metrics: CardMetrics {
        switch self {
        case .small: return CardMetrics(title: 24, subtitle: 16, detail: 14, padding: 20, spacing: 8, corner: 16, closeIcon: 13)
        case .medium: return CardMetrics(title: 30, subtitle: 20, detail: 16, padding: 24, spacing: 10, corner: 18, closeIcon: 14)
        case .large: return CardMetrics(title: 40, subtitle: 26, detail: 20, padding: 30, spacing: 12, corner: 20, closeIcon: 16)
        case .xlarge: return CardMetrics(title: 56, subtitle: 34, detail: 26, padding: 38, spacing: 14, corner: 24, closeIcon: 18)
        }
    }
}

/// Eine Goal-Zielanzeige. Ohne `height` bestimmt der Text die Höhe.
struct GoalCardView: View {
    let card: GoalCard
    let palette: CardPalette
    let size: CardSize
    var height: CGFloat? = nil
    var showsClose = true

    @ViewBuilder
    private var surface: some View {
        let shape = RoundedRectangle(cornerRadius: size.metrics.corner)
        if let gradient = palette.gradient {
            shape.fill(LinearGradient(colors: gradient.colors.map { Color(hex: $0) },
                                      startPoint: UnitPoint(x: gradient.start.x, y: gradient.start.y),
                                      endPoint: UnitPoint(x: gradient.end.x, y: gradient.end.y)))
        } else {
            shape.fill(Color(hex: palette.background))
        }
    }

    var body: some View {
        let m = size.metrics
        // Das X sitzt oben rechts; die ersten Zeilen dürfen nicht darunter laufen.
        let clearX = max(CardLayout.closeSize + 8 - m.padding, 0)
        VStack(alignment: .leading, spacing: m.spacing) {
            if !card.title.isEmpty {
                Text(card.title)
                    .font(.system(size: m.title, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: palette.title))
                    .padding(.trailing, clearX)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !card.subtitle.isEmpty {
                Text(card.subtitle)
                    .font(.system(size: m.subtitle, weight: .medium))
                    .foregroundStyle(Color(hex: palette.subtitle))
                    .padding(.trailing, clearX)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !card.detail.isEmpty {
                Text(card.detail)
                    .font(.system(size: m.detail))
                    .foregroundStyle(Color(hex: palette.text))
                    .lineSpacing(m.detail * 0.2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(m.padding)
        .frame(width: size.width, height: height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: m.corner))
        .background(surface)
        .overlay(RoundedRectangle(cornerRadius: m.corner).strokeBorder(Color(hex: palette.border), lineWidth: 1.5))
        .overlay(alignment: .topTrailing) {
            if showsClose {
                Image(systemName: "xmark")
                    .font(.system(size: m.closeIcon, weight: .semibold))
                    .foregroundStyle(Color(hex: palette.subtitle))
                    .frame(width: CardLayout.closeSize, height: CardLayout.closeSize)
                    .padding(4)
            }
        }
    }
}

enum CardMeasure {
    @MainActor
    static func height(of card: GoalCard, size: CardSize) -> CGFloat {
        let view = NSHostingView(rootView: GoalCardView(card: card, palette: Palettes.mono, size: size))
        return ceil(view.fittingSize.height)
    }
}

/// Was das Overlay gerade zeigt.
@MainActor
final class OverlayModel: ObservableObject {
    struct Entry {
        let card: GoalCard
        let palette: CardPalette
    }

    @Published var layout: OverlayLayout?
    @Published var entries: [String: Entry] = [:]
    @Published var visible: Set<String> = []

    /// Sichtbare Zielanzeigen, die auch wirklich auf den Bildschirm passen.
    var placedVisible: Set<String> {
        Set(layout?.placements.map(\.id) ?? []).intersection(visible)
    }

    var placedVisibleCount: Int { placedVisible.count }
}

/// Inhalt des Overlays. Rein darstellend, Klicks prüft `OverlayController` über die Rechnung in `CardLayout`.
struct OverlayContentView: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        if let layout = model.layout {
            ZStack(alignment: .topLeading) {
                ForEach(layout.placements) { placement in
                    if let entry = model.entries[placement.id] {
                        GoalCardView(card: entry.card, palette: entry.palette.placed(tile: placement.frame, bounds: layout.cardsBounds),
                                     size: layout.size, height: placement.frame.height)
                            .compositingGroup()   // sonst bekäme auch jede Schrift einen eigenen Schatten
                            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                            .opacity(model.visible.contains(placement.id) ? 1 : 0)
                            .animation(.easeOut(duration: 0.18), value: model.visible)
                            .offset(x: placement.frame.minX, y: placement.frame.minY)
                    }
                }
                if let rect = layout.closeAllRect, model.placedVisibleCount >= 2 {
                    Text("Alle schließen")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: Palettes.mono.text))
                        .frame(width: rect.width, height: rect.height)
                        .background(Capsule().fill(Color(hex: Palettes.mono.background)))
                        .overlay(Capsule().strokeBorder(Color(hex: Palettes.mono.border), lineWidth: 1))
                        .offset(x: rect.minX, y: rect.minY)
                }
                if layout.hiddenCount > 0 {
                    Text("\(layout.hiddenCount) weitere passen nicht auf den Bildschirm")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: Palettes.mono.text))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: Palettes.mono.background)))
                        .offset(x: CardLayout.margin, y: layout.canvas.height - CardLayout.margin - CardLayout.footerHeight + 8)
                }
            }
            .frame(width: layout.canvas.width, height: layout.canvas.height, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }
}
