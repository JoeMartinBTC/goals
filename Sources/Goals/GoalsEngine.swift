import AppKit
import GoalsCore

/// Verbindet Karten, Einstellungen, Takt und Overlay. Ein einziger Timer auf den nächsten Termin, sonst keine Arbeit.
@MainActor
final class GoalsEngine: ObservableObject {
    /// Zeiten in Sekunden; der Selbsttest ersetzt sie durch kurze Werte.
    struct Timing {
        var interval: (GoalSettings) -> TimeInterval = { TimeInterval($0.intervalMinutes * 60) }
        var display: (GoalSettings) -> TimeInterval = { TimeInterval($0.displaySeconds) }
    }

    let store: GoalStore
    let settings: GoalSettings
    let overlay: OverlayController
    private(set) var scheduler: ReminderScheduler
    /// Zählt jede Zustandsänderung, damit offene Fenster ihre Statuszeile erneuern.
    @Published private(set) var revision = 0

    private let timing: Timing
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var lastInterval: TimeInterval
    private var lastDisplay: TimeInterval

    init(store: GoalStore, settings: GoalSettings, timing: Timing = Timing()) {
        self.store = store
        self.settings = settings
        self.timing = timing
        overlay = OverlayController(settings: settings)
        lastInterval = timing.interval(settings)
        lastDisplay = timing.display(settings)
        scheduler = ReminderScheduler(interval: lastInterval, display: lastDisplay, jitter: settings.jitter)
    }

    func start() {
        overlay.onClose = { [weak self] id in self?.closeCard(id) }
        overlay.onCloseAll = { [weak self] in self?.closeAll() }
        store.onChange = { [weak self] in self?.cardsChanged() }
        settings.onChange = { [weak self] in self?.settingsChanged() }
        store.start()
        scheduler.updateCards(store.enabledCards.map(\.id), now: Date())
        observeSystem()
        sync()
    }

    func showNow() {
        scheduler.showNow(now: Date())
        sync()
    }

    func closeCard(_ id: String) {
        scheduler.close(id, now: Date())
        var remaining = overlay.model.visible
        remaining.remove(id)
        overlay.model.visible = remaining
        // Karten, die nicht auf den Bildschirm passten, halten die Anzeige nicht offen.
        if overlay.model.placedVisibleCount == 0 { scheduler.closeAll(now: Date()) }
        sync()
    }

    func closeAll() {
        scheduler.closeAll(now: Date())
        sync()
    }

    func suspend(_ reason: ReminderScheduler.SuspendReason) {
        scheduler.suspend(reason, now: Date())
        sync()
    }

    func resume(_ reason: ReminderScheduler.SuspendReason) {
        scheduler.resume(reason, now: Date())
        sync()
    }

    func resetPosition() {
        overlay.resetPosition()
    }

    var statusText: String {
        if store.loadError != nil { return "goals.json ist nicht lesbar" }
        switch scheduler.phase {
        case .idle: return "Keine Karte eingeschaltet"
        case .showing: return "Karten werden gezeigt"
        case .waiting(let until):
            return "Nächste Erinnerung in \(TimeText.remaining(seconds: until.timeIntervalSinceNow))"
        }
    }

    private func cardsChanged() {
        scheduler.updateCards(store.enabledCards.map(\.id), now: Date())
        sync()
    }

    private func settingsChanged() {
        let now = Date()
        scheduler.setJitter(settings.jitter)
        // Nur ein geänderter Takt startet die Wartezeit neu, nicht etwa eine neue Größe.
        let interval = timing.interval(settings)
        if interval != lastInterval {
            lastInterval = interval
            scheduler.setInterval(interval, now: now)
        }
        let display = timing.display(settings)
        if display != lastDisplay {
            lastDisplay = display
            scheduler.setDisplay(display, now: now)
        }
        overlay.invalidateLayout()
        sync()
    }

    private func fire() {
        scheduler.advance(now: Date())
        sync()
    }

    /// Bringt Overlay und Timer auf den Stand des Takts.
    private func sync() {
        let visible = scheduler.visibleIDs
        if visible.isEmpty {
            overlay.hide()
        } else {
            overlay.show(cards: store.enabledCards, visible: Set(visible))
        }
        armTimer()
        revision += 1
    }

    private func armTimer() {
        timer?.invalidate()
        timer = nil
        guard let next = scheduler.nextFire else { return }
        let t = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        t.tolerance = scheduler.isShowing ? 0.05 : 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let pairs: [(NotificationCenter, Notification.Name, ReminderScheduler.SuspendReason, Bool)] = [
            (workspace, NSWorkspace.willSleepNotification, .systemAsleep, true),
            (workspace, NSWorkspace.didWakeNotification, .systemAsleep, false),
            (workspace, NSWorkspace.screensDidSleepNotification, .screensAsleep, true),
            (workspace, NSWorkspace.screensDidWakeNotification, .screensAsleep, false),
            (distributed, Notification.Name("com.apple.screenIsLocked"), .locked, true),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), .locked, false),
            (distributed, Notification.Name("com.apple.screensaver.didstart"), .screensaver, true),
            (distributed, Notification.Name("com.apple.screensaver.didstop"), .screensaver, false),
        ]
        for (center, name, reason, begins) in pairs {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    if begins { self?.suspend(reason) } else { self?.resume(reason) }
                }
            }
            observers.append((center, token))
        }
        let screens = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                             object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.overlay.invalidateLayout()
                self?.sync()
            }
        }
        observers.append((NotificationCenter.default, screens))
    }
}
