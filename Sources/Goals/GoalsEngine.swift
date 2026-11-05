import AppKit
import GoalsCore

/// Meldung eines anderen Prozesses. Sofort zustellen: Goals ist fast immer im Hintergrund,
/// und die Standard-Zustellung darf Meldungen an inaktive Apps zurückhalten.
private final class DistributedObserver: NSObject {
    private let handler: () -> Void

    init(name: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(received), name: Notification.Name(name),
                                                            object: nil, suspensionBehavior: .deliverImmediately)
    }

    @objc private func received() {
        DispatchQueue.main.async(execute: handler)
    }
}

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
    /// Zählt die Timer-Durchläufe für den Selbsttest.
    private(set) var fireCount = 0

    private let timing: Timing
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [DistributedObserver] = []
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
        syncLockState()   // zuerst: Fehlte die Sperr-Meldung, darf ein überfälliger Termin nicht auf den Sperrbildschirm
        scheduler.resume(reason, now: Date())
        sync()
    }

    func resetPosition() {
        overlay.resetPosition()
    }

    var statusText: String {
        if store.loadError != nil { return "goals.json ist nicht lesbar" }
        if store.saveError != nil { return "Speichern fehlgeschlagen" }
        if scheduler.isSuspended { return "Pausiert, solange der Bildschirm ruht oder gesperrt ist" }
        switch scheduler.phase {
        case .idle: return "Keine Zielanzeige eingeschaltet"
        case .showing: return "Zielanzeigen werden gezeigt"
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
        fireCount += 1
        syncLockState()
        scheduler.advance(now: Date())
        sync()
    }

    static var sessionIsLocked: Bool {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool == true
    }

    /// Fragt die Sitzung direkt. So zeigt der Takt auch dann nichts auf dem Sperrbildschirm, wenn eine Meldung verloren ging.
    private func syncLockState() {
        if Self.sessionIsLocked {
            scheduler.suspend(.locked, now: Date())
        } else if scheduler.isSuspended(.locked) {
            // Nach dem Entsperren läuft auch kein Bildschirmschoner mehr, selbst wenn seine Meldung fehlt.
            scheduler.resume(.screensaver, now: Date())
            scheduler.resume(.locked, now: Date())
        }
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
        // Während einer Sperre einmal je Minute die Sitzung abgleichen, falls die Meldung vom Entsperren fehlt.
        guard let next = scheduler.nextFire ?? (scheduler.isSuspended ? Date().addingTimeInterval(60) : nil) else { return }
        let t = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        t.tolerance = scheduler.isShowing ? 0.05 : 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        let local: [(Notification.Name, ReminderScheduler.SuspendReason, Bool)] = [
            (NSWorkspace.willSleepNotification, .systemAsleep, true),
            (NSWorkspace.didWakeNotification, .systemAsleep, false),
            (NSWorkspace.screensDidSleepNotification, .screensAsleep, true),
            (NSWorkspace.screensDidWakeNotification, .screensAsleep, false),
        ]
        for (name, reason, begins) in local {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    if begins { self?.suspend(reason) } else { self?.resume(reason) }
                }
            })
        }

        let remote: [(String, ReminderScheduler.SuspendReason, Bool)] = [
            ("com.apple.screenIsLocked", .locked, true),
            ("com.apple.screenIsUnlocked", .locked, false),
            ("com.apple.screensaver.didstart", .screensaver, true),
            ("com.apple.screensaver.didstop", .screensaver, false),
        ]
        for (name, reason, begins) in remote {
            distributedObservers.append(DistributedObserver(name: name) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if begins { self.suspend(reason) } else { self.resume(reason) }
                }
            })
        }

        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.overlay.invalidateLayout()
                self?.sync()
            }
        })
    }
}
