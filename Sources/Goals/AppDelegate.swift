import AppKit
import GoalsCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let statusSymbol = "target"

    private let store = GoalStore(fileURL: GoalStore.defaultFileURL)
    private let settings = GoalSettings()
    private let autoStart = AutoStart()
    private lazy var engine = GoalsEngine(store: store, settings: settings)
    private lazy var settingsWindow = SettingsWindowController { [unowned self] navigation in
        AnyView(SettingsRootView(store: store, settings: settings, engine: engine, autoStart: autoStart, navigation: navigation))
    }
    private lazy var goalsMenu = GoalsMenu(engine: engine, autoStart: autoStart) { [unowned self] tab in
        settingsWindow.show(tab: tab)
    }
    private var statusItem: NSStatusItem?
    private var dockMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        engine.overlay.contextMenu = { [unowned self] in goalsMenu.build() }
        engine.start()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: AppDelegate.statusSymbol, accessibilityDescription: "Goals") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "G"
        }
        let menu = NSMenu()
        menu.delegate = goalsMenu
        goalsMenu.menuNeedsUpdate(menu)
        item.menu = menu
        statusItem = item

        autoStart.registerOnFirstRun()
        if store.wasCreated { settingsWindow.show() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = goalsMenu.build()
        dockMenu = menu
        return menu
    }

    func applicationWillTerminate(_ notification: Notification) { store.flush() }

    /// Ohne Menü „Bearbeiten“ gingen Kopieren und Einfügen in den Textfeldern nicht.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let app = NSMenu(title: "Goals")
        app.addItem(withTitle: "Über Goals", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let prefs = app.addItem(withTitle: "Einstellungen …", action: #selector(showSettings), keyEquivalent: ",")
        prefs.target = self
        app.addItem(.separator())
        app.addItem(withTitle: "Goals ausblenden", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Goals beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "Goals", action: nil, keyEquivalent: "").submenu = app

        let edit = NSMenu(title: "Bearbeiten")
        edit.addItem(withTitle: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Einfügen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "Bearbeiten", action: nil, keyEquivalent: "").submenu = edit

        let window = NSMenu(title: "Fenster")
        window.addItem(withTitle: "Schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Im Dock ablegen", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(withTitle: "Fenster", action: nil, keyEquivalent: "").submenu = window
        NSApp.windowsMenu = window

        return main
    }

    @objc private func showSettings() { settingsWindow.show() }
}
