# Goals — Projektfakten

Native macOS-App: Goal-Karten erscheinen im eingestellten Takt als Overlay über allem, ohne dem aktiven Programm den Fokus zu nehmen. Swift Package ohne Xcode-Projekt, MIT-Lizenz, Repo `JoeMartinBTC/goals` auf GitHub (privat).

Die Hausregeln stehen in `~/.claude/CLAUDE.md` und gelten hier unverändert. Diese Datei nennt nur, was für dieses Projekt gilt.

## Harte Grenzen

1. **Nur Apple-Frameworks.** `Package.swift` hat keine fremde Abhängigkeit.
2. **Echte Karten nie anfassen.** `~/Library/Application Support/Goals/goals.json` und die UserDefaults von `com.joemartinbtc.Goals` sind Betriebsdaten. Tests, `--selftest` und `--snapshot` arbeiten mit Wegwerf-Dateien.
3. **Kein Klarname im Repo.** Lokale Pfade gehören deshalb nicht in Dateien des Repos. Die Probe steht im Vertrag, den die Brain-Notiz verlinkt, und nicht hier, denn sie enthält die Namen.
4. **Öffentlich wird das Repo nur auf Joes Entscheidung.** Der Befehl steht in der Brain-Notiz.

## Wo was liegt

| Pfad | Inhalt |
|---|---|
| `Sources/GoalsCore/` | reine Logik: Karten, Datei, Takt, Raster, Farben, Einstellungen |
| `Sources/Goals/` | App: Fenster, Karte, Menü, Einstellungsfenster, Prüf-Startmodi |
| `Tests/GoalsCoreTests/` | Tests von `GoalsCore` |
| `Scripts/build_local_app.sh` | baut, signiert ad hoc, installiert nach `/Applications`, startet |
| `docs/ENTWICKLUNG.md` | Aufbau, Entscheidungen, alle Prüfungen, Fallen |
| `CHANGELOG.md` | Stand je Version |

## Bauen und prüfen

```bash
swift test
bash Scripts/build_local_app.sh
/Applications/Goals.app/Contents/MacOS/Goals --selftest
/Applications/Goals.app/Contents/MacOS/Goals --snapshot <ordner>
```

`swift`, `gh` und Schreibzugriffe auf `.git` laufen nicht in der Bash-Sandbox. `--selftest` ist nur aus dem installierten App-Paket aussagekräftig, ein Lauf aus `.build` sagt nichts über die App.

## Mehr

Betrieb, offene Handtests und Stand: `Brain-Notiz 020-Setups/Goals/deployment-guide.md`.
