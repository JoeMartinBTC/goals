import CoreGraphics
import Foundation
import Testing
@testable import GoalsCore

@Suite("Raster")
struct LayoutTests {
    let screen = CGSize(width: 3000, height: 1600)

    func fit(_ n: Int, _ size: CardSize = .medium, available: CGSize? = nil, height: CGFloat = 200) -> OverlayLayout {
        CardLayout.fit(ids: (0..<n).map { "c\($0)" }, preferred: size, available: available ?? screen) { _, _ in height }
    }

    @Test("Eine einzelne Karte steht allein, ohne Knopf „Alle schließen“")
    func singleCard() {
        let l = fit(1)
        #expect(l.placements.count == 1)
        #expect(l.placements[0].frame.width == 480)
        #expect(l.closeAllRect == nil)
    }

    @Test("Bis drei Karten stehen in einer Reihe")
    func threeInRow() {
        let l = fit(3)
        #expect(Set(l.placements.map(\.frame.minY)).count == 1)
        #expect(l.closeAllRect != nil)
    }

    @Test("Vier Karten bilden zwei mal zwei")
    func fourAreSquare() {
        let l = fit(4)
        #expect(Set(l.placements.map(\.frame.minY)).count == 2)
        #expect(Set(l.placements.map(\.frame.minX)).count == 2)
    }

    @Test("Eine unvollständige letzte Reihe steht mittig")
    func lastRowCentered() {
        let l = fit(5)
        let lastRow = l.placements.suffix(2)
        let left = lastRow.first!.frame.minX
        let right = l.canvas.width - lastRow.last!.frame.maxX
        #expect(abs(left - right) < 0.5)
    }

    @Test("Karten einer Reihe sind gleich hoch")
    func rowHeightsEqual() {
        let l = CardLayout.fit(ids: ["a", "b"], preferred: .small, available: screen) { id, _ in id == "a" ? 100 : 300 }
        #expect(l.placements[0].frame.height == 300)
        #expect(l.placements[1].frame.height == 300)
    }

    @Test("Passt die Größe nicht, nimmt das Raster die nächstkleinere")
    func shrinksWhenTooBig() {
        let l = fit(9, .xlarge, available: CGSize(width: 2000, height: 1000), height: 300)
        #expect(l.size != .xlarge)
        #expect(l.hiddenCount == 0)
        #expect(l.canvas.width <= 2000)
        #expect(l.canvas.height <= 1000)
    }

    @Test("Eine zu breite Karte fällt auf die passende Größe zurück")
    func tooWideFallsBack() {
        let l = fit(1, .xlarge, available: CGSize(width: 700, height: 900))
        #expect(l.size == .large)
    }

    @Test("Passt selbst die kleinste Größe nicht, zählt das Raster die fehlenden Karten")
    func dropsAndCounts() {
        let l = fit(40, .small, available: CGSize(width: 800, height: 700), height: 300)
        #expect(l.size == .small)
        #expect(l.hiddenCount > 0)
        #expect(l.placements.count + l.hiddenCount == 40)
        #expect(l.canvas.height <= 700)
    }

    @Test("Eine überlange Karte wird auf den Bildschirm begrenzt")
    func tallCardClamped() {
        let l = fit(1, .small, available: CGSize(width: 800, height: 400), height: 5000)
        #expect(l.canvas.height <= 400)
    }

    @Test("Das Rechteck um alle Karten reicht von der ersten bis zur letzten Karte")
    func cardsBounds() {
        let l = fit(5)
        let frames = l.placements.map(\.frame)
        #expect(l.cardsBounds.minX == frames.map(\.minX).min())
        #expect(l.cardsBounds.maxX == frames.map(\.maxX).max())
        #expect(l.cardsBounds.minY == frames.map(\.minY).min())
        #expect(l.cardsBounds.maxY == frames.map(\.maxY).max())
        #expect(fit(1).cardsBounds == fit(1).placements[0].frame)
    }

    @Test("Klickziele: X, Alle schließen, Karte, Lücke")
    func hitTest() {
        let l = fit(2)
        let visible: Set<String> = ["c0", "c1"]
        let c0 = l.placements[0]
        let close = CGPoint(x: c0.closeRect.midX, y: c0.closeRect.midY)
        #expect(CardLayout.hit(close, in: l, visible: visible) == .close("c0"))
        let body = CGPoint(x: c0.frame.minX + 10, y: c0.frame.maxY - 10)
        #expect(CardLayout.hit(body, in: l, visible: visible) == .card("c0"))
        let all = l.closeAllRect!
        #expect(CardLayout.hit(CGPoint(x: all.midX, y: all.midY), in: l, visible: visible) == .closeAll)
        let gap = CGPoint(x: c0.frame.maxX + 2, y: c0.frame.midY)
        #expect(CardLayout.hit(gap, in: l, visible: visible) == .none)
    }

    @Test("Eine geschlossene Karte ist kein Klickziel, „Alle schließen“ braucht zwei Karten")
    func closedCardNotHit() {
        let l = fit(2)
        let c0 = l.placements[0]
        let visible: Set<String> = ["c1"]
        #expect(CardLayout.hit(CGPoint(x: c0.frame.midX, y: c0.frame.midY), in: l, visible: visible) == .none)
        let all = l.closeAllRect!
        #expect(CardLayout.hit(CGPoint(x: all.midX, y: all.midY), in: l, visible: visible) == .none)
    }

    @Test("Standardort ist die Bildschirmmitte")
    func originIsCentered() {
        let s = CGRect(x: 100, y: 50, width: 2000, height: 1000)
        let o = CardLayout.origin(canvas: CGSize(width: 400, height: 200), screen: s, centerOffset: .zero)
        #expect(o == CGPoint(x: 900, y: 450))
    }

    @Test("Die Position bleibt immer auf dem Bildschirm")
    func originIsClamped() {
        let s = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let o = CardLayout.origin(canvas: CGSize(width: 400, height: 200), screen: s, centerOffset: CGSize(width: 9000, height: -9000))
        #expect(o == CGPoint(x: 600, y: 0))
    }

    @Test("Verschieben und Wiederherstellen ergeben denselben Ort")
    func offsetRoundTrip() {
        let s = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let canvas = CGSize(width: 400, height: 200)
        let origin = CGPoint(x: 123, y: 456)
        let offset = CardLayout.centerOffset(origin: origin, canvas: canvas, screen: s)
        #expect(CardLayout.origin(canvas: canvas, screen: s, centerOffset: offset) == origin)
    }
}

@Suite("Farben")
struct PaletteTests {
    func luminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(hex >> 16) + 0.7152 * channel(hex >> 8) + 0.0722 * channel(hex)
    }

    func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let (x, y) = (Double((a >> shift) & 0xFF), Double((b >> shift) & 0xFF))
            return UInt32((x + (y - x) * t).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    /// Alle Farben, die hinter der Schrift liegen können: bei einem Verlauf zehn Stufen je Abschnitt.
    func surface(_ p: CardPalette) -> [UInt32] {
        guard let g = p.gradient else { return [p.background] }
        let segments = g.colors.count - 1
        return (0...(segments * 10)).map { step in
            let i = min(step / 10, segments - 1)
            return mix(g.colors[i], g.colors[i + 1], Double(step - i * 10) / 10)
        }
    }

    func isClose(_ a: CGPoint, _ b: CGPoint) -> Bool {
        abs(a.x - b.x) < 0.001 && abs(a.y - b.y) < 0.001
    }

    @Test("Acht Schemen mit einem Verlauf je Karte, vier über die ganze Fläche")
    func schemeCounts() {
        #expect(ColorSchemeKind.perCard.count == 8)
        #expect(ColorSchemeKind.wholeArea.count == 4)
        #expect(ColorSchemeKind.allCases.count == 13)
        #expect(Set(ColorSchemeKind.allCases.map(\.title)).count == 13)
        for scheme in ColorSchemeKind.perCard {
            #expect(Palettes.palette(index: 0, mode: .color, scheme: scheme, custom: nil).gradient?.spansCards == false)
        }
        for scheme in ColorSchemeKind.wholeArea {
            #expect(Palettes.palette(index: 0, mode: .color, scheme: scheme, custom: nil).gradient?.spansCards == true)
        }
    }

    @Test("Je Karte: Die ersten sechs Karten zeigen sechs verschiedene Verläufe", arguments: ColorSchemeKind.perCard)
    func eachCardHasOwnGradient(scheme: ColorSchemeKind) {
        let gradients = (0..<6).compactMap { Palettes.palette(index: $0, mode: .color, scheme: scheme, custom: nil).gradient?.colors }
        #expect(gradients.count == 6)
        #expect(Set(gradients).count == 6)
    }

    @Test("Ganze Fläche: Alle Schemen zeigen verschiedene Verläufe mit mindestens drei Farben")
    func wholeAreaGradientsDiffer() {
        let gradients = ColorSchemeKind.wholeArea.compactMap { Palettes.palette(index: 0, mode: .color, scheme: $0, custom: nil).gradient?.colors }
        #expect(Set(gradients).count == 4)
        #expect(gradients.allSatisfy { $0.count >= 3 })
    }

    @Test("Einfarbig und Eigene haben keinen Verlauf")
    func flatStaysFlat() {
        let c = CardColors(background: "#101010", title: "#FF0000", text: "#00FF00")
        #expect(Palettes.palette(index: 0, mode: .mono, scheme: .morgenrot, custom: nil).gradient == nil)
        #expect(Palettes.palette(index: 0, mode: .color, scheme: .eigene, custom: c).gradient == nil)
    }

    @Test("Der Winkel zählt wie in CSS", arguments: [
        (90.0, CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5)),
        (180.0, CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1)),
        (135.0, CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)),
        (45.0, CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 0)),
    ])
    func angleLikeCSS(angle: Double, start: CGPoint, end: CGPoint) {
        let g = CardGradient(colors: [0, 0xFFFFFF], angle: angle)
        #expect(isClose(g.start, start))
        #expect(isClose(g.end, end))
    }

    @Test("Ganze Fläche: Jede Karte zeigt einen Ausschnitt derselben Achse")
    func sharedAxis() {
        let g = CardGradient(colors: [0, 0xFFFFFF], angle: 120, spansCards: true)
        let bounds = CGRect(x: 16, y: 16, width: 1476, height: 410)
        let start = CGPoint(x: bounds.minX + g.start.x * bounds.width, y: bounds.minY + g.start.y * bounds.height)
        let end = CGPoint(x: bounds.minX + g.end.x * bounds.width, y: bounds.minY + g.end.y * bounds.height)
        let tiles = [CGRect(x: 16, y: 16, width: 480, height: 196), CGRect(x: 514, y: 16, width: 480, height: 196),
                     CGRect(x: 1012, y: 230, width: 480, height: 196)]
        for tile in tiles {
            let s = g.section(tile: tile, bounds: bounds)
            #expect(s.colors == g.colors)
            #expect(isClose(CGPoint(x: tile.minX + s.start.x * tile.width, y: tile.minY + s.start.y * tile.height), start))
            #expect(isClose(CGPoint(x: tile.minX + s.end.x * tile.width, y: tile.minY + s.end.y * tile.height), end))
        }
    }

    @Test("Ganze Fläche: Die Lage bestimmt den Ausschnitt, eine Karte allein zeigt alles")
    func placedWholeArea() {
        let p = Palettes.palette(index: 0, mode: .color, scheme: .morgenrot, custom: nil)
        let bounds = CGRect(x: 16, y: 16, width: 978, height: 196)
        let left = p.placed(tile: CGRect(x: 16, y: 16, width: 480, height: 196), bounds: bounds)
        let right = p.placed(tile: CGRect(x: 514, y: 16, width: 480, height: 196), bounds: bounds)
        #expect(left.gradient != right.gradient)
        let alone = p.placed(tile: bounds, bounds: bounds)
        #expect(isClose(alone.gradient!.start, p.gradient!.start))
        #expect(isClose(alone.gradient!.end, p.gradient!.end))
    }

    @Test("Je Karte: Die Lage ändert den Verlauf nicht")
    func placedPerCard() {
        let p = Palettes.palette(index: 1, mode: .color, scheme: .fest, custom: nil)
        let placed = p.placed(tile: CGRect(x: 514, y: 16, width: 480, height: 196), bounds: CGRect(x: 16, y: 16, width: 978, height: 196))
        #expect(placed == p)
    }

    @Test("Einfarbig entspricht den Farben der Uhr")
    func monoIsClock() {
        let p = Palettes.palette(index: 3, mode: .mono, scheme: .signal, custom: nil)
        #expect(p.title == 0xF7931A)
        #expect(p.background == 0x0C0B0A)
    }

    @Test("Jede Schrift ist überall auf ihrem Hintergrund gut lesbar", arguments: ColorSchemeKind.allCases)
    func contrastIsReadable(scheme: ColorSchemeKind) {
        for i in 0..<12 {
            let p = Palettes.palette(index: i, mode: .color, scheme: scheme, custom: nil)
            for color in surface(p) {
                #expect(contrast(p.title, color) >= 4.5, "Titel, Karte \(i)")
                #expect(contrast(p.subtitle, color) >= 4.5, "Unterzeile, Karte \(i)")
                #expect(contrast(p.text, color) >= 4.5, "Text, Karte \(i)")
            }
        }
    }

    @Test("Im Modus Farbig bekommt jede Karte eine eigene Farbe", arguments: ColorSchemeKind.perCard)
    func eachCardDiffers(scheme: ColorSchemeKind) {
        let all = (0..<4).map { Palettes.palette(index: $0, mode: .color, scheme: scheme, custom: nil) }
        #expect(Set(all.map(\.title)).count == 4 || Set(all.map(\.background)).count == 4)
    }

    @Test("Eigene Farben gelten nur im Schema Eigene")
    func customOnlyInCustomScheme() {
        let c = CardColors(background: "#101010", title: "#FF0000", text: "#00FF00")
        let own = Palettes.palette(index: 0, mode: .color, scheme: .eigene, custom: c)
        #expect(own.background == 0x101010)
        #expect(own.title == 0xFF0000)
        #expect(own.text == 0x00FF00)
        let other = Palettes.palette(index: 0, mode: .color, scheme: .nacht, custom: c)
        #expect(other.background != 0x101010)
        let mono = Palettes.palette(index: 0, mode: .mono, scheme: .eigene, custom: c)
        #expect(mono.background == 0x0C0B0A)
    }

    @Test("Ungültige Farbangaben fallen auf den Standard zurück")
    func invalidHexFallsBack() {
        let c = CardColors(background: "grün", title: "#12", text: "#GGGGGG")
        let p = Palettes.palette(index: 0, mode: .color, scheme: .eigene, custom: c)
        #expect(p.background == 0x0C0B0A)
        #expect(p.title == 0xF7931A)
        #expect(p.text == 0xF0E6D4)
    }

    @Test("Hex-Umwandlung")
    func hexParsing() {
        #expect(Palettes.parseHex("#F7931A") == 0xF7931A)
        #expect(Palettes.parseHex("f7931a") == 0xF7931A)
        #expect(Palettes.parseHex("xyz") == nil)
        #expect(Palettes.hexString(0x0000FF) == "#0000FF")
    }
}

@Suite("Einstellungen")
struct SettingsTests {
    func defaults() -> UserDefaults {
        let name = "goals-test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test("Vier Größen mit den vereinbarten Breiten")
    func sizes() {
        #expect(CardSize.allCases.map(\.width) == [360, 480, 640, 900])
    }

    @Test("Standardwerte")
    func standardValues() {
        let s = GoalSettings(defaults: defaults())
        #expect(s.size == .medium)
        #expect(s.displaySeconds == 15)
        #expect(s.intervalMinutes == 60)
        #expect(s.jitter == false)
        #expect(s.colorMode == .mono)
        #expect(s.scheme == .metall)
        #expect(s.positionOffset == .zero)
    }

    @Test("Ungültige gespeicherte Werte fallen auf den Standard zurück")
    func garbageFallsBack() {
        let d = defaults()
        d.set(7, forKey: "displaySeconds")
        d.set(-5, forKey: "intervalMinutes")
        d.set("riesig", forKey: "size")
        let s = GoalSettings(defaults: d)
        #expect(s.displaySeconds == 15)
        #expect(s.intervalMinutes == 60)
        #expect(s.size == .medium)
    }

    @Test("Werte überstehen den Neustart, der freie Takt ist begrenzt")
    func persistence() {
        let d = defaults()
        let s = GoalSettings(defaults: d)
        s.size = .xlarge
        s.displaySeconds = 30
        s.intervalMinutes = 45
        s.jitter = true
        s.colorMode = .color
        s.scheme = .morgenrot
        s.positionOffset = CGSize(width: 12, height: -34)
        let again = GoalSettings(defaults: d)
        #expect(again.size == .xlarge)
        #expect(again.displaySeconds == 30)
        #expect(again.intervalMinutes == 45)
        #expect(again.jitter)
        #expect(again.colorMode == .color)
        #expect(again.scheme == .morgenrot)
        #expect(again.positionOffset == CGSize(width: 12, height: -34))
        s.intervalMinutes = 99_999
        #expect(s.intervalMinutes == GoalSettings.maxIntervalMinutes)
        s.intervalMinutes = 0
        #expect(s.intervalMinutes == 1)
    }

    @Test("Ein begrenzter Takt wird gespeichert und gemeldet", arguments: [(0, 1), (99_999, GoalSettings.maxIntervalMinutes)])
    func clampedIntervalIsApplied(input: Int, expected: Int) {
        let d = defaults()
        let s = GoalSettings(defaults: d)
        var calls = 0
        s.onChange = { calls += 1 }
        s.intervalMinutes = input
        #expect(s.intervalMinutes == expected)
        #expect(d.integer(forKey: "intervalMinutes") == expected)
        #expect(calls == 1)
    }

    @Test("Anzeigedauer nimmt nur die vier Stufen an")
    func displayOnlyPresets() {
        let s = GoalSettings(defaults: defaults())
        s.displaySeconds = 22
        #expect(s.displaySeconds == 15)
        #expect(GoalSettings.displayOptions == [5, 10, 15, 30])
        #expect(GoalSettings.intervalOptions == [1, 15, 30, 60, 120, 240])
    }

    @Test("Änderungen melden sich beim Beobachter")
    func changeCallback() {
        let s = GoalSettings(defaults: defaults())
        var calls = 0
        s.onChange = { calls += 1 }
        s.size = .large
        s.jitter = true
        #expect(calls == 2)
    }
}
