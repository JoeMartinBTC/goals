import AppKit
import GoalsCore
import SwiftUI

/// Liegt über allem, auch über Vollbild-Apps, und nimmt dem aktiven Programm nie den Fokus.
final class OverlayPanel: NSPanel {
    var onLeftDown: ((NSEvent) -> Void)?
    var onRightDown: ((NSEvent) -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // SwiftUI-Taps kommen in einem nicht aktivierenden Fenster nicht verlässlich an; deshalb prüft der Controller jeden Klick selbst.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown: onLeftDown?(event)
        case .rightMouseDown: onRightDown?(event)
        default: super.sendEvent(event)
        }
    }
}

@MainActor
final class OverlayController {
    let panel: OverlayPanel
    let model = OverlayModel()
    private(set) var isShown = false
    var onClose: ((String) -> Void)?
    var onCloseAll: (() -> Void)?
    var contextMenu: (() -> NSMenu)?

    private let settings: GoalSettings
    private let host: NSHostingView<OverlayContentView>
    private var layoutKey = ""
    private var fadeGeneration = 0

    init(settings: GoalSettings) {
        self.settings = settings
        panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        panel.sharingType = .none

        host = NSHostingView(rootView: OverlayContentView(model: model))
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        panel.onLeftDown = { [weak self] event in self?.handleLeftDown(event) }
        panel.onRightDown = { [weak self] event in self?.handleRightDown(event) }
    }

    /// Der Hauptbildschirm trägt die Menüleiste. `NSScreen.main` wäre der Bildschirm mit dem aktiven Fenster.
    private var screenFrame: CGRect {
        NSScreen.screens.first?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    /// Zeigt die sichtbaren Karten. Neu gerechnet wird nur bei geändertem Inhalt: Schließt man eine Karte,
    /// bleiben die anderen stehen, damit das nächste X nicht wegspringt.
    func show(cards: [GoalCard], visible: Set<String>) {
        var entries: [String: OverlayModel.Entry] = [:]
        for (index, card) in cards.enumerated() {
            entries[card.id] = OverlayModel.Entry(card: card, palette: Palettes.palette(
                index: index, mode: settings.colorMode, scheme: settings.scheme, custom: card.colors))
        }
        model.entries = entries
        model.visible = visible

        let screen = screenFrame
        let key = "\(settings.size.rawValue)|\(screen)|" + cards.map { "\($0.id)\u{1}\($0.title)\u{1}\($0.subtitle)\u{1}\($0.detail)" }.joined(separator: "\u{2}")
        if key != layoutKey || model.layout == nil {
            layoutKey = key
            let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
            let layout = CardLayout.fit(ids: cards.map(\.id), preferred: settings.size, available: screen.size) { id, size in
                byID[id].map { CardMeasure.height(of: $0, size: size) } ?? 0
            }
            model.layout = layout
            placePanel(layout: layout, screen: screen)
        }
        reveal()
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        fadeGeneration += 1
        let generation = fadeGeneration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, generation == self.fadeGeneration else { return }
                self.panel.orderOut(nil)
                self.model.visible = []
            }
        })
    }

    /// Bildschirm oder Position haben sich geändert: beim nächsten `show` neu platzieren.
    func invalidateLayout() {
        layoutKey = ""
    }

    func resetPosition() {
        settings.positionOffset = .zero
        invalidateLayout()
        if let layout = model.layout { placePanel(layout: layout, screen: screenFrame) }
    }

    private func placePanel(layout: OverlayLayout, screen: CGRect) {
        let origin = CardLayout.origin(canvas: layout.canvas, screen: screen, centerOffset: settings.positionOffset)
        panel.setFrame(NSRect(origin: origin, size: layout.canvas), display: isShown)
    }

    private func reveal() {
        guard !isShown else { return }
        isShown = true
        fadeGeneration += 1
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }
    }

    private func handleLeftDown(_ event: NSEvent) {
        guard let layout = model.layout else { return }
        let point = CGPoint(x: event.locationInWindow.x, y: layout.canvas.height - event.locationInWindow.y)
        switch CardLayout.hit(point, in: layout, visible: model.placedVisible) {
        case .close(let id):
            onClose?(id)
        case .closeAll:
            onCloseAll?()
        case .card:
            panel.performDrag(with: event)
            settings.positionOffset = CardLayout.centerOffset(origin: panel.frame.origin, canvas: layout.canvas, screen: screenFrame)
        case .none:
            break
        }
    }

    private func handleRightDown(_ event: NSEvent) {
        guard let menu = contextMenu?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: host)
    }
}
