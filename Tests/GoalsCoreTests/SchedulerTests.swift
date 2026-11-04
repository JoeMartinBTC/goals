import Foundation
import Testing
@testable import GoalsCore

@Suite("Takt")
struct SchedulerTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func scheduler(interval: TimeInterval = 600, display: TimeInterval = 15, jitter: Bool = false,
                   factor: Double = 1, cards: [String] = ["a", "b"]) -> ReminderScheduler {
        var s = ReminderScheduler(interval: interval, display: display, jitter: jitter, randomFactor: { factor })
        s.updateCards(cards, now: t0)
        return s
    }

    @Test("Ohne eingeschaltete Karte läuft kein Takt")
    func idleWithoutCards() {
        let s = scheduler(cards: [])
        #expect(s.phase == .idle)
        #expect(s.nextFire == nil)
    }

    @Test("Die erste eingeschaltete Karte startet den Takt")
    func firstCardStartsInterval() {
        #expect(scheduler().phase == .waiting(until: t0.addingTimeInterval(600)))
    }

    @Test("Vor dem Termin erscheint nichts")
    func notBeforeDue() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(599))
        #expect(s.visibleIDs.isEmpty)
    }

    @Test("Am Termin erscheinen alle aktiven Karten gemeinsam")
    func showsAtDue() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        #expect(s.visibleIDs == ["a", "b"])
        #expect(s.phase == .showing(until: t0.addingTimeInterval(615)))
    }

    @Test("Karten verschwinden nach der Anzeigedauer, der Takt zählt ab dort")
    func vanishesAndCountsFromVanish() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        let end = t0.addingTimeInterval(615)
        s.advance(now: end)
        #expect(s.visibleIDs.isEmpty)
        #expect(s.phase == .waiting(until: end.addingTimeInterval(600)))
    }

    @Test("Eine geschlossene Karte geht, die andere bleibt")
    func closeOneKeepsOther() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        s.close("a", now: t0.addingTimeInterval(601))
        #expect(s.visibleIDs == ["b"])
    }

    @Test("Schließen der letzten Karte beendet die Anzeige, der Takt zählt ab dem Schließen")
    func closeLastCountsFromClose() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        s.close("a", now: t0.addingTimeInterval(601))
        let last = t0.addingTimeInterval(603)
        s.close("b", now: last)
        #expect(s.phase == .waiting(until: last.addingTimeInterval(600)))
    }

    @Test("Alle schließen beendet die Anzeige")
    func closeAllEnds() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        let at = t0.addingTimeInterval(602)
        s.closeAll(now: at)
        #expect(s.visibleIDs.isEmpty)
        #expect(s.phase == .waiting(until: at.addingTimeInterval(600)))
    }

    @Test("Eine geschlossene Karte kommt beim nächsten Mal wieder")
    func closedCardReturns() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        s.close("a", now: t0.addingTimeInterval(601))
        s.advance(now: t0.addingTimeInterval(615))
        s.advance(now: t0.addingTimeInterval(1215))
        #expect(s.visibleIDs == ["a", "b"])
    }

    @Test("Schaltet man alle Karten ab, endet die Anzeige und der Takt ruht")
    func disablingAllGoesIdle() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        s.updateCards([], now: t0.addingTimeInterval(601))
        #expect(s.phase == .idle)
    }

    @Test("Schaltet man eine sichtbare Karte ab, bleibt die andere")
    func disablingOneKeepsOther() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        s.updateCards(["b"], now: t0.addingTimeInterval(601))
        #expect(s.visibleIDs == ["b"])
    }

    @Test("Jetzt zeigen wirkt sofort")
    func showNowWorks() {
        var s = scheduler()
        s.showNow(now: t0.addingTimeInterval(10))
        #expect(s.visibleIDs == ["a", "b"])
        #expect(s.phase == .showing(until: t0.addingTimeInterval(25)))
    }

    @Test("Jetzt zeigen ohne Karte tut nichts")
    func showNowWithoutCards() {
        var s = scheduler(cards: [])
        s.showNow(now: t0)
        #expect(s.phase == .idle)
    }

    @Test("Ein neuer Takt gilt ab jetzt")
    func intervalChangeRestarts() {
        var s = scheduler()
        let at = t0.addingTimeInterval(100)
        s.setInterval(60, now: at)
        #expect(s.phase == .waiting(until: at.addingTimeInterval(60)))
    }

    @Test("Eine neue Anzeigedauer gilt auch für die laufende Anzeige")
    func displayChangeWhileShowing() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        let at = t0.addingTimeInterval(601)
        s.setDisplay(5, now: at)
        #expect(s.phase == .showing(until: at.addingTimeInterval(5)))
    }

    @Test("Streuung bleibt innerhalb von ± 20 Prozent", arguments: [0.8, 1.2])
    func jitterApplies(factor: Double) {
        let s = scheduler(jitter: true, factor: factor)
        #expect(s.phase == .waiting(until: t0.addingTimeInterval(600 * factor)))
    }

    @Test("Ohne Streuung ist der Takt exakt, auch bei einem Zufallswert")
    func jitterOffIsExact() {
        let s = scheduler(jitter: false, factor: 1.2)
        #expect(s.phase == .waiting(until: t0.addingTimeInterval(600)))
    }

    @Test("Der Zufallsfaktor des Standards bleibt in den Grenzen")
    func defaultFactorBounds() {
        for _ in 0..<500 {
            #expect((0.8...1.2).contains(ReminderScheduler.defaultRandomFactor()))
        }
    }

    @Test("Sperre blendet aus, ein fälliger Termin wartet bis zum Entsperren")
    func lockHidesAndOverdueShowsOnUnlock() {
        var s = scheduler()
        s.advance(now: t0.addingTimeInterval(600))
        s.suspend(.locked, now: t0.addingTimeInterval(601))
        #expect(s.visibleIDs.isEmpty)
        let afterDue = t0.addingTimeInterval(601 + 700)
        s.advance(now: afterDue)
        #expect(s.visibleIDs.isEmpty)
        s.resume(.locked, now: afterDue)
        #expect(s.visibleIDs == ["a", "b"])
    }

    @Test("Entsperren vor dem Termin ändert nichts")
    func unlockBeforeDueKeepsWaiting() {
        var s = scheduler()
        s.suspend(.locked, now: t0.addingTimeInterval(1))
        s.resume(.locked, now: t0.addingTimeInterval(2))
        #expect(s.phase == .waiting(until: t0.addingTimeInterval(600)))
    }

    @Test("Zwei Sperrgründe müssen beide enden")
    func twoReasonsNeedBothResume() {
        var s = scheduler()
        s.suspend(.locked, now: t0)
        s.suspend(.screensAsleep, now: t0)
        let due = t0.addingTimeInterval(700)
        s.resume(.screensAsleep, now: due)
        s.advance(now: due)
        #expect(s.visibleIDs.isEmpty)
        s.resume(.locked, now: due)
        #expect(s.visibleIDs == ["a", "b"])
    }

    @Test("Jetzt zeigen wirkt nicht bei gesperrtem Bildschirm")
    func showNowWhileSuspended() {
        var s = scheduler()
        s.suspend(.locked, now: t0)
        s.showNow(now: t0)
        #expect(s.visibleIDs.isEmpty)
    }
}
