import Testing
@testable import GoalsCore

@Suite("Zeitangaben")
struct TimeTextTests {
    @Test("Minuten und Stunden")
    func minutes() {
        #expect(TimeText.minutes(15) == "15 Min.")
        #expect(TimeText.minutes(60) == "1 Std.")
        #expect(TimeText.minutes(90) == "1 Std. 30 Min.")
    }

    @Test("Restzeit wird aufgerundet und zeigt mindestens eine Minute")
    func remaining() {
        #expect(TimeText.remaining(seconds: 61) == "2 Min.")
        #expect(TimeText.remaining(seconds: 0) == "1 Min.")
    }
}
