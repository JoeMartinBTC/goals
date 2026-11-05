# Goals — Projektfakten

Native macOS-App: Zielanzeigen erscheinen im eingestellten Takt als Overlay über allem, ohne dem aktiven Programm den Fokus zu nehmen. Swift Package ohne Xcode-Projekt, MIT-Lizenz, Repo `JoeMartinBTC/goals` auf GitHub (öffentlich seit 2026-11-05). Projektseite: <https://librarycompass.com/goals/>, Quelle im Repo LibraryCompass unter `web/goals/`, Bilder aus `--snapshot` (Ordner `seite/`).

Die Hausregeln stehen in `~/.claude/CLAUDE.md` und gelten hier unverändert. Diese Datei nennt nur, was für dieses Projekt gilt.

## Harte Grenzen

1. **Nur Apple-Frameworks.** `Package.swift` hat keine fremde Abhängigkeit.
2. **Echte Zielanzeigen nie anfassen.** `~/Library/Application Support/Goals/goals.json` und die UserDefaults von `com.joemartinbtc.Goals` sind Betriebsdaten. Tests, `--selftest` und `--snapshot` arbeiten mit Wegwerf-Dateien.
3. **Kein Klarname im Repo.** Lokale Pfade gehören deshalb nicht in Dateien des Repos. Die Probe steht im Vertrag, den die Brain-Notiz verlinkt, und nicht hier, denn sie enthält die Namen.
4. **Das Repo ist öffentlich.** Jeder Push ist sofort sichtbar, die Klarnamen-Probe läuft deshalb vor dem Push.

## Wo was liegt

| Pfad | Inhalt |
|---|---|
| `Sources/GoalsCore/` | reine Logik: Zielanzeigen, Datei, Takt, Raster, Farben, Einstellungen |
| `Sources/Goals/` | App: Fenster, Zielanzeige, Menü, Einstellungsfenster, Prüf-Startmodi |
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

`swift`, `gh`, `--selftest` und Schreibzugriffe auf `.git` laufen nicht in der Bash-Sandbox. `--selftest` ist nur aus dem installierten App-Paket aussagekräftig, ein Lauf aus `.build` sagt nichts über die App.

Die Einstellungen liest die Goal-App nur beim Start. Ein `defaults write` an der laufenden Goal-App wirkt erst nach einem Neustart, und der setzt die Wartezeit zurück.

## Mehr

Betrieb, offene Handtests und Stand: `Brain-Notiz 020-Setups/Goals/deployment-guide.md`.
