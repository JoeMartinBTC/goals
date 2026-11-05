import AppKit
import GoalsCore
import ServiceManagement

/// Autostart über `SMAppService`. Eintrag einmalig beim ersten Start, danach entscheidet der Schalter.
@MainActor
final class AutoStart: ObservableObject {
    @Published private(set) var isOn = SMAppService.mainApp.status == .enabled

    func registerOnFirstRun() {
        guard !UserDefaults.standard.bool(forKey: "autostartInitialized") else { return }
        set(true)
        // Erst nach Erfolg merken, sonst käme ein gescheiterter Eintrag nie wieder dran.
        if isOn { UserDefaults.standard.set(true, forKey: "autostartInitialized") }
    }

    func set(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on { try service.register() } else { try service.unregister() }
        } catch {
            NSLog("Goals: Anmeldeobjekt \(on ? "register" : "unregister") fehlgeschlagen: \(error)")
        }
        isOn = service.status == .enabled
    }
}

private final class ActionItem: NSMenuItem {
    private var handler: (() -> Void)?

    convenience init(_ title: String, checked: Bool = false, enabled: Bool = true, key: String = "", handler: @escaping () -> Void) {
        self.init(title: title, action: #selector(run), keyEquivalent: key)
        self.handler = handler
        target = self
        state = checked ? .on : .off
        isEnabled = enabled
    }

    @objc private func run() { handler?() }
}

/// Dasselbe Menü für Menüleiste, Dock und Rechtsklick auf eine Zielanzeige.
@MainActor
final class GoalsMenu: NSObject, NSMenuDelegate {
    private let engine: GoalsEngine
    private let autoStart: AutoStart
    private let openSettings: (SettingsNavigation.Tab) -> Void

    init(engine: GoalsEngine, autoStart: AutoStart, openSettings: @escaping (SettingsNavigation.Tab) -> Void) {
        self.engine = engine
        self.autoStart = autoStart
        self.openSettings = openSettings
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        fill(menu)
    }

    func build() -> NSMenu {
        let menu = NSMenu()
        fill(menu)
        return menu
    }

    private func fill(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        let settings = engine.settings
        let store = engine.store

        menu.addItem(ActionItem("Jetzt zeigen", enabled: !store.enabledCards.isEmpty) { [engine] in engine.showNow() })
        let status = NSMenuItem(title: engine.statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let cards = store.cards.map { card in
            ActionItem(card.title.isEmpty ? "Ohne Überschrift" : card.title, checked: card.isEnabled, enabled: store.loadError == nil) {
                store.setEnabled(card.id, !card.isEnabled)
            }
        }
        menu.addItem(submenu("Zielanzeigen", cards.isEmpty ? [ActionItem("Noch keine Zielanzeige", enabled: false) {}] : cards))

        menu.addItem(submenu("Größe", CardSize.allCases.map { size in
            ActionItem("\(size.title) (\(Int(size.width)) pt)", checked: settings.size == size) { settings.size = size }
        }))
        menu.addItem(submenu("Anzeigedauer", GoalSettings.displayOptions.map { seconds in
            ActionItem("\(seconds) Sekunden", checked: settings.displaySeconds == seconds) { settings.displaySeconds = seconds }
        }))

        var interval = GoalSettings.intervalOptions.map { minutes in
            ActionItem("Alle \(TimeText.minutes(minutes))", checked: settings.intervalMinutes == minutes) { settings.intervalMinutes = minutes }
        }
        let isCustom = !GoalSettings.intervalOptions.contains(settings.intervalMinutes)
        interval.append(ActionItem(isCustom ? "Eigener Wert: \(TimeText.minutes(settings.intervalMinutes)) …" : "Eigener Wert …", checked: isCustom) { [openSettings] in
            openSettings(.display)
        })
        menu.addItem(submenu("Takt", interval))

        let schemeItem = { (scheme: ColorSchemeKind) -> NSMenuItem in
            ActionItem(scheme.title, checked: settings.colorMode == .color && settings.scheme == scheme) {
                settings.scheme = scheme
                settings.colorMode = .color
            }
        }
        var colors: [NSMenuItem] = [ActionItem("Einfarbig", checked: settings.colorMode == .mono) { settings.colorMode = .mono }]
        colors.append(.sectionHeader(title: "Verlauf je Zielanzeige"))
        colors += ColorSchemeKind.perCard.map(schemeItem)
        colors.append(.sectionHeader(title: "Verlauf über die ganze Fläche"))
        colors += ColorSchemeKind.wholeArea.map(schemeItem)
        colors.append(.separator())
        colors.append(schemeItem(.eigene))
        menu.addItem(submenu("Farbe", colors))
        menu.addItem(ActionItem("Takt streuen (± 20 %)", checked: settings.jitter) { settings.jitter.toggle() })

        menu.addItem(.separator())
        menu.addItem(ActionItem("Position zurücksetzen") { [engine] in engine.resetPosition() })
        menu.addItem(ActionItem("Einstellungen …", key: ",") { [openSettings] in openSettings(.cards) })
        menu.addItem(ActionItem("Beim Anmelden starten", checked: autoStart.isOn) { [autoStart] in autoStart.set(!autoStart.isOn) })
        menu.addItem(.separator())
        menu.addItem(ActionItem("Goals beenden") { NSApp.terminate(nil) })
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu(title: title)
        sub.autoenablesItems = false
        items.forEach(sub.addItem)
        item.submenu = sub
        return item
    }
}
