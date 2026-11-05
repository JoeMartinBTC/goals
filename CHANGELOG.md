# Änderungen

## 1.1.0 (2026-11-05)

- Acht Schemen mit einem eigenen Verlauf je Karte: Metall, Signal, Pastell und Nacht haben jetzt Verläufe, Fest, Minze, Himmel und Glut sind neu.
- Vier neue Schemen mit einem einzigen Verlauf über alle Karten: Morgenrot, Lagune, Polarlicht, Abendrot.
- Menü und Einstellungsfenster zeigen die Schemen in zwei Gruppen. Im Einstellungsfenster ist „Schema“ jetzt eine Auswahlliste.
- Einfarbig und Eigene bleiben ohne Verlauf.

## 1.0.0 (2026-11-04)

Erste Fassung.

### App

- Goal-Karten mit Überschrift, Unterüberschrift und Erklärung, jede einzeln ein- und ausschaltbar.
- Anzeige über allem, auch über Vollbild-Programmen, ohne dem aktiven Programm den Fokus zu nehmen.
- Vier Größen, einstellbare Anzeigedauer, Takt ab dem Verschwinden der Karten, wahlweise mit Streuung.
- Einfarbig oder farbig mit vier Schemen und eigenen Farben je Karte.
- Menüleiste, Dock, Rechtsklick auf die Karte und Einstellungsfenster. Alles ist im Betrieb änderbar.
- Die Karten liegen lesbar in `goals.json`, Änderungen von außen wirken sofort.

### Verhalten nach der Abnahme

- Während einer Sperre gibt es keinen Termin. Ein fälliger Termin folgt beim Entsperren.
- Sperrmeldungen kommen sofort an, zusätzlich fragt der Timer die Sitzung ab. Entsperren hebt auch den Bildschirmschoner auf.
- Eine `goals.json` ohne `cards` gilt als kaputt und bleibt unangetastet.
- Eine Änderung von außen vor dem Speichern gewinnt, auch eine unlesbare Datei zählt als Konflikt.
- Ein gescheitertes Speichern wird gemeldet. Das Neuladen hebt die Meldung wieder auf.
- Das Löschen einer kaputten Datei hebt die Sperre auf.

### Prüfung

- `--selftest` prüft 29 Punkte im echten Fenster, `--snapshot` rendert 26 Bilder, `--show-for` zeigt Prüfkarten für einen Versuch von außen.
- `--autostart-status` nennt den Stand des Anmeldeobjekts, weil `sfltool dumpbtm` auf macOS 27 auf eine Admin-Freigabe wartet.
- Die Prüfmodi laufen auch aus dem installierten App-Paket. Der Selbsttest gibt dem Fensterdienst bis zu zwei Sekunden Zeit, statt fest zu warten.
