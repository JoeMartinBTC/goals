# Entwicklung

Swift Package ohne Xcode-Projekt. Das Bundle baut `Scripts/build_local_app.sh`.

## Aufbau

| Teil | Datei | Aufgabe |
|---|---|---|
| `GoalsCore` | `GoalCard.swift`, `GoalStore.swift`, `FileWatcher.swift` | Karten, `goals.json`, Beobachtung des Pfads |
| | `ReminderScheduler.swift` | Takt als reine Logik: Die Zeit kommt von außen, keine Timer |
| | `CardLayout.swift` | Raster, Klickziele, Position als reine Rechnung |
| | `Palettes.swift`, `GoalSettings.swift`, `TimeText.swift` | Farben, Einstellungen, Zeitangaben |
| `Goals` | `GoalsEngine.swift` | Verbindet alles, ein einziger Timer auf den nächsten Termin |
| | `OverlayController.swift` | Fenster, Einblenden, Klicks |
| | `GoalCardView.swift` | Karte und Overlay-Inhalt, rein darstellend |
| | `GoalsMenu.swift`, `SettingsView.swift`, `AppDelegate.swift` | Menü, Einstellungsfenster, App |
| | `SelfTest.swift`, `Snapshot.swift` | Prüf-Startmodi |

## Entscheidungen

- **Fenster:** `NSPanel` mit `.nonactivatingPanel`, `canBecomeKey == false`, Ebene `.statusBar`, `collectionBehavior` mit `.canJoinAllSpaces` und `.fullScreenAuxiliary`. So liegt es auch über Vollbild-Apps, obwohl Goals eine normale Dock-App ist.
- **`.stationary` fehlt absichtlich.** `CGWindowList` meldet solche Fenster auf skalierten Bildschirmen verkleinert, das würde die Fensterprobe verfälschen.
- **Klicks:** `OverlayPanel.sendEvent` fängt Maus-Ereignisse ab, `CardLayout.hit` rechnet das Ziel aus. Der SwiftUI-Inhalt hat `allowsHitTesting(false)`. Damit ist jedes Klickziel ohne Bildschirm testbar.
- **Kein Umbruch beim Schließen:** Das Raster wird nur bei geändertem Inhalt neu gerechnet. Schließt man eine Karte, bleiben die anderen stehen, damit das nächste X nicht wegspringt.
- **Hauptbildschirm:** `NSScreen.screens.first`, nicht `NSScreen.main`. Letzteres ist der Bildschirm mit dem aktiven Fenster.
- **Takt ab dem Verschwinden:** Auch das Schließen der letzten Karte startet die Wartezeit. Ein neuer Takt gilt ab jetzt, eine neue Anzeigedauer auch für die laufende Anzeige.
- **Kaputte Datei:** `GoalStore` sperrt dann jede Änderung und schreibt nichts. Fehlt die Datei im Betrieb, schreibt die App den letzten guten Stand zurück und hebt die Sperre auf. Eine Datei ohne `cards` gilt als kaputt.
- **Gleichzeitige Änderung:** Vor jedem Speichern vergleicht `GoalStore` die Platte mit dem zuletzt gelesenen Stand. Weicht sie ab, gewinnt die Datei, denn eine verlorene Eingabe sieht man sofort, eine überschriebene Datei nie.
- **Keine Dauerarbeit:** Es gibt nur einen Timer auf den nächsten Termin, keine `TimelineView` und kein Abfragen im Overlay. Während einer Sperre gibt es keinen Termin (`nextFire == nil`); stattdessen gleicht ein Timer einmal je Minute die Sitzung ab.
- **Sperre:** Die Meldungen `com.apple.screenIsLocked` und `…Unlocked` kommen mit `.deliverImmediately`, weil Goals fast immer im Hintergrund ist. Zusätzlich fragt jeder Timer-Durchlauf `CGSessionCopyCurrentDictionary`, damit eine verlorene Meldung nichts auf den Sperrbildschirm bringt.

## Prüf-Startmodi

- `--selftest`: Takt, Anzeigedauer, Klicks, vier Breiten, Datei von außen, kaputte Datei, Sperre, Fensterflags. Sichtbarkeit fragt er beim Fensterdienst ab und gibt ihm bis zu zwei Sekunden Zeit, damit eine ausgelastete Maschine kein falsches Rot ergibt. `frontmostUnchanged` wird nur rot, wenn der Selbsttest selbst nach vorn kommt; ein Wechsel zwischen anderen Programmen zählt nicht. Klicks gehen direkt per `sendEvent` an das Fenster, weil Klicks von außen Bedienungshilfen-Rechte brauchen. Die Sperre ruft er direkt auf, die echten Systemmeldungen laufen nicht mit. Nutzt eine Wegwerf-Datei und Wegwerf-Einstellungen.
- `--autostart-status`: nennt den Stand des Anmeldeobjekts.
- `--snapshot <ordner>`: 24 Bilder der Karten (vier Größen, sechs Farbdarstellungen) und zwei des Einstellungsfensters. Die Karten rendert `ImageRenderer`, das Fenster `cacheDisplay`, denn `ImageRenderer` zeichnet keine nativen Bedienelemente.
- `--show-for <sekunden> [--allow-capture]`: zeigt zwei Prüfkarten und nennt ihr Rechteck. So lässt sich die Aufzeichnungs-Sperre von außen prüfen.

## Fallen

- SwiftPM legt das Programm je nach Toolchain woanders ab. Immer `swift build --show-bin-path` benutzen.
- `.shadow` auf einer Ansicht mit Hintergrund gibt auch jeder Schrift einen Schatten. Davor gehört `.compositingGroup()`.
- Synthetisiertes `Decodable` ignoriert Standardwerte. `GoalCard` und `GoalFile` haben deshalb eigene Initialisierer mit `decodeIfPresent`.
- `open(path, O_EVTONLY)` hängt an der Inode. Atomares Speichern ersetzt sie, deshalb öffnet `FileWatcher` bei `.delete` und `.rename` den Pfad neu.
- Die Prüfmodi laufen ohne `app.run()`. Unter einer schon gelaufenen Bundle-ID ordnet AppKit dann keine Fenster an, obwohl `isVisible` `true` meldet. `main.swift` setzt deshalb für diese Modi `ApplePersistenceIgnoreState`, nur im Prozess. Ein grüner Lauf aus `.build` sagt darüber nichts, denn dort gibt es keine Bundle-ID. Geprüft wird das installierte Paket.
- Den normalen Betrieb prüft man ohne echte Daten mit einem Wegwerf-Ordner: `CFFIXED_USER_HOME=<ordner> /Applications/Goals.app/Contents/MacOS/Goals -intervalMinutes 1 -displaySeconds 5 -autostartInitialized YES`. Die Karten liegen dann unter `<ordner>/Library/Application Support/Goals/goals.json`. Einstellungen aus diesem Ordner liest die App nicht, deshalb stehen sie als Startargumente im Befehl.
- Prüfen im Vollbild: Ein Hilfsprogramm geht mit eigenem Fenster per `toggleFullScreen` in den Vollbildmodus und startet dort `--selftest`. Die Prüfung `listedOnCurrentSpace` zeigt dann, ob das Overlay auf dem Vollbild-Space liegt.
- Ob eine Aufzeichnung die Karten wirklich auslässt, zeigt nur ein echter Versuch: `--show-for 15` starten und ein Bildschirmfoto machen. Das braucht das Recht auf Bildschirmaufnahme.
