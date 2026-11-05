# Goals

Native macOS-App, die deine Ziele in einem einstellbaren Takt als Karten über alles legt, was gerade auf dem Bildschirm läuft. Sie bleiben ein paar Sekunden stehen und verschwinden wieder von selbst. Dein aktives Programm behält dabei den Fokus, du kannst einfach weitertippen.

![Drei Karten in der einfarbigen Darstellung](docs/karten-einfarbig.png)

![Drei Karten im Schema Fest, jede mit eigenem Verlauf](docs/karten-farbig.png)

![Drei Karten im Schema Morgenrot, ein Verlauf über alle Karten](docs/karten-flaeche.png)

## Was sie kann

- **Goal-Karten** mit Überschrift, Unterüberschrift und Erklärung, jede einzeln ein- und ausschaltbar. Eine einzelne Karte steht allein, mehrere stehen gemeinsam in einem automatischen Raster.
- **Vier Größen:** 360, 480, 640 und 900 pt Breite. Passt das Raster nicht auf den Bildschirm, nimmt die App die nächstkleinere Größe.
- **Takt:** alle 15 Min., 30 Min., 1 Std., 2 Std., 4 Std. oder ein eigener Wert. Er zählt ab dem Verschwinden der Karten. Wahlweise streut er um ± 20 %.
- **Anzeigedauer:** 5, 10, 15 oder 30 Sekunden für alle Karten gleichzeitig.
- **Wegklicken:** X je Karte, ab zwei Karten zusätzlich „Alle schließen“.
- **Farbe:** einfarbig in Bitcoin-Orange auf Dunkel, oder farbig mit Verläufen. Acht Schemen geben jeder Karte einen eigenen Verlauf: Metall, Signal, Pastell, Nacht, Fest, Minze, Himmel, Glut. Vier Schemen legen einen einzigen Verlauf über alle Karten zusammen: Morgenrot, Lagune, Polarlicht, Abendrot. Dazu kommen eigene Farben je Karte.
- **Ort:** Mitte des Hauptbildschirms, per Ziehen verschiebbar, die Position bleibt gespeichert.
- **Aufzeichnung:** Das Fenster verlangt von macOS, nicht in Bildschirmfreigaben und Aufnahmen zu erscheinen (`NSWindow.sharingType = .none`). Verlass dich nicht darauf: In den Apple Developer Forums wird berichtet, dass die Aufnahme von QuickTime solche Fenster trotzdem erfasst. Prüfe es mit deinem Programm, siehe `--show-for` in [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md).
- Bei gesperrtem Bildschirm, Bildschirmschoner und im Ruhezustand erscheint nichts. Ein fälliger Termin folgt beim Entsperren.

![Einstellungsfenster](docs/einstellungen.png)

## Bedienung

Das Symbol in der Menüleiste, das Dock-Symbol und der Rechtsklick auf eine Karte öffnen dasselbe Menü: Jetzt zeigen, Karten, Größe, Anzeigedauer, Takt, Farbe, Position zurücksetzen, Einstellungen, Autostart, Beenden. Ein Klick auf das Dock-Symbol öffnet die Einstellungen.

Ab Werk gilt: Größe „Mittel“ (480 pt), 15 Sekunden Anzeigedauer, Takt 1 Stunde ohne Streuung, einfarbig. Ein eigener Takt darf zwischen 1 Minute und 24 Stunden liegen.

## Die Datei

Die Karten liegen lesbar in `~/Library/Application Support/Goals/goals.json`. Änderungen von außen wirken sofort, auch von Editoren, die atomar speichern. Treffen sie auf eine ungespeicherte Eingabe in der App, gewinnt die Datei. Eine Datei, die nicht lesbar ist, bleibt unangetastet: Die App meldet das und speichert nichts, bis sie wieder lesbar ist. Löschst du sie, schreibt die App den letzten guten Stand zurück.

```json
{
  "cards": [
    { "title": "Fokus", "subtitle": "Eine Sache zuerst fertig machen", "detail": "Warum dieses Ziel zählt." },
    { "title": "Gesundheit", "enabled": false }
  ],
  "version": 1
}
```

Alle Schlüssel außer `cards` sind freiwillig. Eigene Farben stehen je Karte unter `colors` mit `background`, `title` und `text` als Hex-Wert. Unbekannte Schlüssel gehen beim nächsten Speichern in der App verloren.

## Bauen

Voraussetzung: macOS 14 oder neuer und Xcode.

```bash
bash Scripts/build_local_app.sh
```

Das Skript baut die App, signiert sie ad hoc, installiert sie nach `/Applications` und startet sie. Beim ersten Start öffnet sich das Einstellungsfenster mit einer ausgeschalteten Beispielkarte, und die App trägt sich als Anmeldeobjekt ein.

## Prüfen

```bash
swift test
/Applications/Goals.app/Contents/MacOS/Goals --selftest
/Applications/Goals.app/Contents/MacOS/Goals --snapshot /tmp/goals-bilder
```

`--selftest` läuft rund 10 Sekunden im echten Fenster mit einer Wegwerf-Datei und gibt JSON aus. Aufbau, alle Prüfungen und Fallen: [docs/ENTWICKLUNG.md](docs/ENTWICKLUNG.md). Der Stand je Version steht in [CHANGELOG.md](CHANGELOG.md).

## Entfernen

Schalte zuerst im Menü den Autostart aus und beende die App. Danach entfernen diese Befehle die App, deine Karten und die Einstellungen:

```bash
rm -rf /Applications/Goals.app
rm -rf ~/Library/Application\ Support/Goals
defaults delete com.joemartinbtc.Goals
```

## Lizenz

MIT
