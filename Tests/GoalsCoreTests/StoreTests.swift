import Foundation
import Testing
@testable import GoalsCore

@MainActor
@Suite("Ablage", .serialized)
struct StoreTests {
    func tempFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("goals-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("goals.json")
    }

    func wait(until condition: () -> Bool, seconds: Double = 4) async throws {
        let end = Date().addingTimeInterval(seconds)
        while !condition(), Date() < end {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @Test("Der erste Start legt eine ausgeschaltete Beispielkarte an")
    func firstStartCreatesExample() throws {
        let url = try tempFile()
        let store = GoalStore(fileURL: url)
        store.load()
        #expect(store.wasCreated)
        #expect(store.cards.count == 1)
        #expect(store.cards[0].isEnabled == false)
        #expect(store.enabledCards.isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Eine vorhandene Datei gilt nicht als erster Start")
    func existingFileIsNoFirstStart() throws {
        let url = try tempFile()
        try #"{"cards":[]}"#.write(to: url, atomically: true, encoding: .utf8)
        let store = GoalStore(fileURL: url)
        store.load()
        #expect(!store.wasCreated)
        #expect(store.cards.isEmpty)
    }

    @Test("Fehlende Schlüssel bekommen Standardwerte")
    func missingKeysUseDefaults() throws {
        let url = try tempFile()
        try #"{"cards":[{"title":"Nur Titel"}]}"#.write(to: url, atomically: true, encoding: .utf8)
        let store = GoalStore(fileURL: url)
        store.load()
        #expect(store.loadError == nil)
        #expect(store.cards[0].title == "Nur Titel")
        #expect(store.cards[0].subtitle == "")
        #expect(store.cards[0].detail == "")
        #expect(store.cards[0].isEnabled == true)
        #expect(store.cards[0].colors == nil)
        #expect(!store.cards[0].id.isEmpty)
    }

    @Test("Fehlende und doppelte IDs werden eindeutig")
    func idsBecomeUnique() throws {
        let url = try tempFile()
        try #"{"cards":[{"title":"A"},{"title":"B"},{"id":"x","title":"C"},{"id":"x","title":"D"}]}"#
            .write(to: url, atomically: true, encoding: .utf8)
        let store = GoalStore(fileURL: url)
        store.load()
        #expect(Set(store.cards.map(\.id)).count == 4)
    }

    @Test("Speichern schreibt lesbare Schlüssel und übersteht den Rundlauf")
    func saveRoundTrip() throws {
        let url = try tempFile()
        let store = GoalStore(fileURL: url)
        store.load()
        let card = store.add()
        var edited = card
        edited.title = "Fokus"
        edited.subtitle = "Eine Sache"
        edited.detail = "Erklärung"
        edited.colors = CardColors(background: "#112233", title: "#445566", text: "#778899")
        store.update(edited)
        store.flush()

        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("\"title\""))
        #expect(text.contains("\"enabled\""))
        #expect(text.contains("Fokus"))

        let again = GoalStore(fileURL: url)
        again.load()
        #expect(again.cards == store.cards)
    }

    @Test("Eine kaputte Datei bleibt unangetastet und sperrt Änderungen")
    func brokenFileNotOverwritten() throws {
        let url = try tempFile()
        let store = GoalStore(fileURL: url)
        store.load()
        let before = store.cards
        let broken = "{ das ist kein json"
        try broken.write(to: url, atomically: true, encoding: .utf8)
        store.reload()
        #expect(store.loadError != nil)
        #expect(store.cards == before)

        store.setEnabled(before[0].id, true)
        _ = store.add()
        store.remove(before[0].id)
        store.flush()
        #expect(store.cards == before)
        #expect(try String(contentsOf: url, encoding: .utf8) == broken)
    }

    @Test("Eine reparierte Datei hebt die Sperre auf")
    func fixedFileClearsError() throws {
        let url = try tempFile()
        let store = GoalStore(fileURL: url)
        store.load()
        try "kaputt".write(to: url, atomically: true, encoding: .utf8)
        store.reload()
        #expect(store.loadError != nil)
        try #"{"cards":[{"title":"Wieder da"}]}"#.write(to: url, atomically: true, encoding: .utf8)
        store.reload()
        #expect(store.loadError == nil)
        #expect(store.cards.first?.title == "Wieder da")
    }

    @Test("Atomares Ersetzen von außen und späteres Schreiben kommen beide an")
    func watcherSurvivesAtomicReplace() async throws {
        let url = try tempFile()
        let store = GoalStore(fileURL: url)
        store.start()
        defer { store.stop() }

        let replacement = url.deletingLastPathComponent().appendingPathComponent("neu.json")
        try #"{"cards":[{"title":"Ersetzt"}]}"#.write(to: replacement, atomically: false, encoding: .utf8)
        #expect(rename(replacement.path, url.path) == 0)
        try await wait { store.cards.first?.title == "Ersetzt" }
        #expect(store.cards.first?.title == "Ersetzt")

        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(#"{"cards":[{"title":"Geschrieben"}]}"#.utf8))
        try handle.close()
        try await wait { store.cards.first?.title == "Geschrieben" }
        #expect(store.cards.first?.title == "Geschrieben")
    }

    @Test("Wird die Datei im Betrieb gelöscht, schreibt die App ihren Stand zurück")
    func deletedFileIsRestored() async throws {
        let url = try tempFile()
        try #"{"cards":[{"title":"Bleibt"}]}"#.write(to: url, atomically: true, encoding: .utf8)
        let store = GoalStore(fileURL: url)
        store.start()
        defer { store.stop() }
        try FileManager.default.removeItem(at: url)
        try await wait { FileManager.default.fileExists(atPath: url.path) }
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("Bleibt"))
        #expect(store.cards.first?.title == "Bleibt")
    }

    @Test("Wird eine kaputte Datei gelöscht, schreibt die App den letzten guten Stand zurück und hebt die Sperre auf")
    func deletedBrokenFileRecovers() throws {
        let url = try tempFile()
        try #"{"cards":[{"title":"Gut"}]}"#.write(to: url, atomically: true, encoding: .utf8)
        let store = GoalStore(fileURL: url)
        store.load()
        try "kaputt".write(to: url, atomically: true, encoding: .utf8)
        store.reload()
        #expect(store.loadError != nil)
        try FileManager.default.removeItem(at: url)
        store.reload()
        #expect(store.loadError == nil)
        #expect(try String(contentsOf: url, encoding: .utf8).contains("Gut"))
        _ = store.add()
        #expect(store.cards.count == 2)
    }

    @Test("Eine Datei ohne Zielanzeigenliste gilt als kaputt und wird nicht überschrieben", arguments: ["{}", #"{"card":[{"title":"Tippfehler"}]}"#])
    func missingCardsIsBroken(text: String) throws {
        let url = try tempFile()
        try text.write(to: url, atomically: true, encoding: .utf8)
        let store = GoalStore(fileURL: url)
        store.load()
        #expect(store.loadError != nil)
        _ = store.add()
        store.flush()
        #expect(try String(contentsOf: url, encoding: .utf8) == text)
    }

    @Test("Eine gültige Änderung von außen kurz vor dem Speichern gewinnt")
    func externalChangeBeforeSaveWins() throws {
        let url = try tempFile()
        let store = GoalStore(fileURL: url)
        store.load()
        _ = store.add()
        let external = #"{"cards":[{"title":"Von außen"}]}"#
        try external.write(to: url, atomically: true, encoding: .utf8)
        store.flush()
        #expect(try String(contentsOf: url, encoding: .utf8) == external)
        #expect(store.cards.map(\.title) == ["Von außen"])
    }

    @Test("Eine kaputte Datei kurz vor dem Speichern bleibt unangetastet")
    func brokenBeforeSaveIsKept() throws {
        let url = try tempFile()
        let store = GoalStore(fileURL: url)
        store.load()
        _ = store.add()
        let broken = "{ kaputt"
        try broken.write(to: url, atomically: true, encoding: .utf8)
        store.flush()
        #expect(try String(contentsOf: url, encoding: .utf8) == broken)
        #expect(store.loadError != nil)
    }

    @Test("Ein gescheitertes Speichern wird gemeldet, ein gelungenes hebt die Meldung auf")
    func saveErrorIsReported() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("goals-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let blocker = dir.appendingPathComponent("sub")
        try "eine Datei statt eines Ordners".write(to: blocker, atomically: true, encoding: .utf8)
        let store = GoalStore(fileURL: blocker.appendingPathComponent("goals.json"))
        store.load()
        #expect(store.saveError != nil)
        try FileManager.default.removeItem(at: blocker)
        _ = store.add()
        store.flush()
        #expect(store.saveError == nil)
    }

    @Test("Eine unlesbare Datei gilt als Konflikt und wird nicht ersetzt")
    func unreadableFileIsKept() throws {
        let url = try tempFile()
        let store = GoalStore(fileURL: url)
        store.load()
        let before = try Data(contentsOf: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
        _ = store.add()
        store.flush()
        #expect(store.loadError != nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        #expect(try Data(contentsOf: url) == before)
    }

    @Test("Übernimmt die App den Stand der Datei, verschwindet die Meldung über ein gescheitertes Speichern")
    func reloadClearsSaveError() throws {
        let url = try tempFile()
        let dir = url.deletingLastPathComponent()
        let store = GoalStore(fileURL: url)
        store.load()
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path) }
        _ = store.add()
        store.flush()
        #expect(store.saveError != nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        try #"{"cards":[{"title":"Von außen"}]}"#.write(to: url, atomically: true, encoding: .utf8)
        store.reload()
        #expect(store.cards.map(\.title) == ["Von außen"])
        #expect(store.saveError == nil)
    }

    @Test("Hinzufügen, Abschalten, Verschieben, Löschen")
    func mutators() throws {
        let store = GoalStore(fileURL: try tempFile())
        store.load()
        let a = store.add()
        let b = store.add()
        #expect(store.cards.count == 3)
        store.setEnabled(a.id, false)
        #expect(store.cards.first { $0.id == a.id }?.isEnabled == false)
        store.move(from: IndexSet(integer: 2), to: 0)
        #expect(store.cards[0].id == b.id)
        store.remove(b.id)
        #expect(store.cards.count == 2)
    }

    @Test("Änderungen melden sich beim Beobachter")
    func changeCallback() throws {
        let store = GoalStore(fileURL: try tempFile())
        store.load()
        var calls = 0
        store.onChange = { calls += 1 }
        _ = store.add()
        #expect(calls == 1)
    }
}
