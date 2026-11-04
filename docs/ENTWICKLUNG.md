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
- **Kaputte Datei:** `GoalStore` sperrt dann jede Änderung und schreibt nichts. Fehlt die Datei im Betrieb, schreibt die App ihren Stand aus dem Speicher zurück.
- **Keine Dauerarbeit:** Es gibt nur einen Timer auf den nächsten Termin, keine `TimelineView` und kein Abfragen im Overlay.

## Prüf-Startmodi

- `--selftest`: Takt, Anzeigedauer, Klicks, vier Breiten, Datei von außen, kaputte Datei, Sperre, Fensterflags. Klicks gehen direkt per `sendEvent` an das Fenster, weil Klicks von außen Bedienungshilfen-Rechte brauchen. Nutzt eine Wegwerf-Datei und Wegwerf-Einstellungen.
- `--snapshot <ordner>`: 24 Bilder der Karten (vier Größen, sechs Farbdarstellungen) und zwei des Einstellungsfensters. Die Karten rendert `ImageRenderer`, das Fenster `cacheDisplay`, denn `ImageRenderer` zeichnet keine nativen Bedienelemente.
- `--show-for <sekunden> [--allow-capture]`: zeigt zwei Prüfkarten und nennt ihr Rechteck. So lässt sich die Aufzeichnungs-Sperre von außen prüfen.

## Fallen

- SwiftPM legt das Programm je nach Toolchain woanders ab. Immer `swift build --show-bin-path` benutzen.
- `.shadow` auf einer Ansicht mit Hintergrund gibt auch jeder Schrift einen Schatten. Davor gehört `.compositingGroup()`.
- Synthetisiertes `Decodable` ignoriert Standardwerte. `GoalCard` und `GoalFile` haben deshalb eigene Initialisierer mit `decodeIfPresent`.
- `open(path, O_EVTONLY)` hängt an der Inode. Atomares Speichern ersetzt sie, deshalb öffnet `FileWatcher` bei `.delete` und `.rename` den Pfad neu.
- Prüfen im Vollbild: Ein Hilfsprogramm geht mit eigenem Fenster per `toggleFullScreen` in den Vollbildmodus und startet dort `--selftest`. Die Prüfung `listedOnCurrentSpace` zeigt dann, ob das Overlay auf dem Vollbild-Space liegt.
- Ob eine Aufzeichnung die Karten wirklich auslässt, zeigt nur ein echter Versuch: `--show-for 15` starten und ein Bildschirmfoto machen. Das braucht das Recht auf Bildschirmaufnahme.
