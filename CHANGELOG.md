# Änderungen

## 1.1.2 (2026-11-05)

- Die Oberfläche sagt „Zielanzeige“ statt „Karte“, weil das Wort an Landkarten denken ließ. Die Datei `goals.json` bleibt unverändert gültig.
- Tests und Prüfmodi halten ihre Einstellungen nur noch im Speicher und hinterlassen keine Dateien mehr in den Preferences.

## 1.1.1 (2026-11-05)

- Neuer Takt „1 Min.“ im Menü und im Einstellungsfenster, damit sich die Wiederholung schnell prüfen lässt.
- Tests und `--selftest` prüfen jetzt auch, dass der Takt über mehrere Runden weiterläuft (`secondRoundAppears`).
- `--snapshot` schreibt zusätzlich die Bilder der Projektseite nach `seite/`.

## 1.1.0 (2026-11-05)

- Acht Schemen mit einem eigenen Verlauf je Zielanzeige: Metall, Signal, Pastell und Nacht haben jetzt Verläufe, Fest, Minze, Himmel und Glut sind neu.
- Vier neue Schemen mit einem einzigen Verlauf über alle Zielanzeigen: Morgenrot, Lagune, Polarlicht, Abendrot.
- Menü und Einstellungsfenster zeigen die Schemen in zwei Gruppen. Im Einstellungsfenster ist „Schema“ jetzt eine Auswahlliste.
- Einfarbig und Eigene bleiben ohne Verlauf.
- `--snapshot` schreibt zusätzlich zwei Übersichten aller Schemen mit je sechs Zielanzeigen.

## 1.0.0 (2026-11-04)

Erste Fassung.

### App

- Zielanzeigen mit Überschrift, Unterüberschrift und Erklärung, jede einzeln ein- und ausschaltbar.
- Anzeige über allem, auch über Vollbild-Programmen, ohne dem aktiven Programm den Fokus zu nehmen.
- Vier Größen, einstellbare Anzeigedauer, Takt ab dem Verschwinden der Zielanzeigen, wahlweise mit Streuung.
- Einfarbig oder farbig mit vier Schemen und eigenen Farben je Zielanzeige.
- Menüleiste, Dock, Rechtsklick auf die Zielanzeige und Einstellungsfenster. Alles ist im Betrieb änderbar.
- Die Zielanzeigen liegen lesbar in `goals.json`, Änderungen von außen wirken sofort.

### Verhalten nach der Abnahme

- Während einer Sperre gibt es keinen Termin. Ein fälliger Termin folgt beim Entsperren.
- Sperrmeldungen kommen sofort an, zusätzlich fragt der Timer die Sitzung ab. Entsperren hebt auch den Bildschirmschoner auf.
- Eine `goals.json` ohne `cards` gilt als kaputt und bleibt unangetastet.
- Eine Änderung von außen vor dem Speichern gewinnt, auch eine unlesbare Datei zählt als Konflikt.
- Ein gescheitertes Speichern wird gemeldet. Das Neuladen hebt die Meldung wieder auf.
- Das Löschen einer kaputten Datei hebt die Sperre auf.

### Prüfung

- `--selftest` prüft 29 Punkte im echten Fenster, `--snapshot` rendert 26 Bilder, `--show-for` zeigt Prüfanzeigen für einen Versuch von außen.
- `--autostart-status` nennt den Stand des Anmeldeobjekts, weil `sfltool dumpbtm` auf macOS 27 auf eine Admin-Freigabe wartet.
- Die Prüfmodi laufen auch aus dem installierten App-Paket. Der Selbsttest gibt dem Fensterdienst bis zu zwei Sekunden Zeit, statt fest zu warten.
