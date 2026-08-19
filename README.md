# RPG-Pokemon

Ein Godot-4-Desktopspiel als kleiner, erweiterbarer 2D-RPG-Prototyp mit Wait-ATB-Kampfsystem.

## Aktueller Stand

Der erste technische Meilenstein enthält:

- Godot-4-Projektgerüst
- datengetrennte Monster- und Attackendefinitionen
- 6 Teamplätze, davon bis zu 4 gleichzeitig aktiv
- Wait-ATB für Monster plus unabhängige Trainer-ATB
- zentrale Aggro-Zielregel inklusive Gleichstand über Teamposition
- konfigurierbare Aggro-Halbierung nach offensiven Einzelzielaktionen
- Warten, Verfehlen und unterschiedliche Erholungszeiten
- vorbereitete Eröffnungsphase / Runde 0
- einfache Test-Overworld mit Weg, Gras, Trainer und Heilstation
- einfache Battle-Sandbox mit Dummy-Monstern
- Headless-Testskript für Kernregeln

## Starten

1. Godot 4 installieren.
2. Diesen Ordner in Godot über `project.godot` öffnen.
3. Projekt starten.

Steuerung in der Testkarte:

- Pfeiltasten / WASD: bewegen
- `E`: Trainer ansprechen, wenn man nahe steht
- Gras kann zufällig einen Kampf auslösen
- Heilstation heilt beim Betreten

Im Kampf pausiert die Zeit, sobald eines deiner Monster oder der Trainer handlungsbereit ist. Die Oberfläche bietet dann die zulässigen Aktionen an.

## Ordner

- `data/` – JSON-Daten für Monster und Attacken
- `scripts/battle/` – Kampflogik
- `scripts/world/` – Testwelt
- `scripts/ui/` – Darstellung/HUD
- `scenes/` – Godot-Szenen
- `tests/` – automatisierbare Kernregeltests
- `assets/` – später eigene Grafiken; keine Pokémon-/Nintendo-Assets werden mitgeliefert

## Eigene Sprites später einsetzen

Lege eigene, rechtmäßig nutzbare Dateien in `assets/monsters/`, `assets/trainers/`, `assets/world/` oder `assets/ui/`. Die Dummy-Darstellung ist absichtlich abstrakt und kann später datengetrieben durch Texturen ersetzt werden.

## Validierung

Wenn Godot lokal verfügbar ist:

```bash
godot --headless --path . --quit
godot --headless --path . --script tests/test_battle_rules.gd
```

Die aktuelle Cloud-Laufzeit dieser Entwicklung enthält kein Godot-Binary; deshalb konnte die Godot-Engine hier nicht ausgeführt werden.

## Nächster sinnvoller Schritt

Nach diesem Fundament: Battle-UI iterieren, Wechsel/Fangfluss vollständig interaktiv machen, Status- und Opening-Phase im UI ausbauen und anschließend die Testkarte grafisch verfeinern.
