import Foundation

/// Wann Karten erscheinen und verschwinden. Reine Logik ohne Uhr und Timer: Die Zeit kommt von außen,
/// die App stellt einen einzigen Timer auf `nextFire` und ruft dann `advance`.
public struct ReminderScheduler {
    public enum Phase: Equatable {
        case idle
        case waiting(until: Date)
        case showing(until: Date)
    }

    public enum SuspendReason: Hashable {
        case locked, screensAsleep, screensaver, systemAsleep
    }

    public private(set) var phase: Phase = .idle
    private var enabledIDs: [String] = []
    private var closedIDs = Set<String>()
    private var suspensions = Set<SuspendReason>()
    private var interval: TimeInterval
    private var display: TimeInterval
    private var jitter: Bool
    private let randomFactor: () -> Double

    public init(interval: TimeInterval, display: TimeInterval, jitter: Bool,
                randomFactor: @escaping () -> Double = ReminderScheduler.defaultRandomFactor) {
        self.interval = interval
        self.display = display
        self.jitter = jitter
        self.randomFactor = randomFactor
    }

    public static func defaultRandomFactor() -> Double { Double.random(in: 0.8...1.2) }

    public var nextFire: Date? {
        switch phase {
        case .idle: return nil
        case .waiting(let until), .showing(let until): return until
        }
    }

    public var isShowing: Bool {
        if case .showing = phase { return true }
        return false
    }

    public var isSuspended: Bool { !suspensions.isEmpty }

    /// Karten, die gerade auf dem Bildschirm stehen, in der Reihenfolge der Liste.
    public var visibleIDs: [String] {
        guard isShowing else { return [] }
        return enabledIDs.filter { !closedIDs.contains($0) }
    }

    public mutating func advance(now: Date) {
        switch phase {
        case .idle:
            break
        case .waiting(let until):
            if now >= until, !isSuspended { show(now: now) }
        case .showing(let until):
            if now >= until { endShowing(now: now) }
        }
    }

    public mutating func updateCards(_ ids: [String], now: Date) {
        enabledIDs = ids
        if ids.isEmpty {
            closedIDs = []
            phase = .idle
            return
        }
        switch phase {
        case .idle:
            wait(now: now)
        case .showing:
            if visibleIDs.isEmpty { endShowing(now: now) }
        case .waiting:
            break
        }
    }

    public mutating func showNow(now: Date) {
        guard !enabledIDs.isEmpty, !isSuspended else { return }
        show(now: now)
    }

    public mutating func close(_ id: String, now: Date) {
        guard isShowing else { return }
        closedIDs.insert(id)
        if visibleIDs.isEmpty { endShowing(now: now) }
    }

    public mutating func closeAll(now: Date) {
        guard isShowing else { return }
        endShowing(now: now)
    }

    public mutating func setInterval(_ value: TimeInterval, now: Date) {
        interval = value
        if case .waiting = phase { wait(now: now) }
    }

    public mutating func setDisplay(_ value: TimeInterval, now: Date) {
        display = value
        if isShowing { phase = .showing(until: now.addingTimeInterval(value)) }
    }

    public mutating func setJitter(_ value: Bool) {
        jitter = value
    }

    public mutating func suspend(_ reason: SuspendReason, now: Date) {
        suspensions.insert(reason)
        if isShowing { endShowing(now: now) }
    }

    public mutating func resume(_ reason: SuspendReason, now: Date) {
        suspensions.remove(reason)
        advance(now: now)
    }

    private mutating func show(now: Date) {
        closedIDs = []
        phase = .showing(until: now.addingTimeInterval(display))
    }

    private mutating func endShowing(now: Date) {
        closedIDs = []
        if enabledIDs.isEmpty {
            phase = .idle
        } else {
            wait(now: now)
        }
    }

    private mutating func wait(now: Date) {
        let delay = jitter ? interval * randomFactor() : interval
        phase = .waiting(until: now.addingTimeInterval(delay))
    }
}
