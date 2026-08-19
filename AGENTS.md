# AGENTS.md

## Verbindliche Entwicklungsregeln

Dieses Repository wird primär per natürlicher Sprache gepflegt. Der Nutzer ist kein Entwickler und soll keine manuellen Codearbeiten übernehmen müssen.

### Technischer Rahmen

- Godot 4, GDScript, Desktop, 2D.
- Keine Web-/HTML-Umsetzung als Ersatz.
- Daten, Spiellogik und Darstellung strikt trennen.
- Keine großen monolithischen Skripte.
- Keine Magic Numbers für zentrale Kampfregeln; zentrale Konfiguration verwenden.
- Erweiterbarkeit für Monster, Attacken, Items, Statuszustände, Trainer und Karten erhalten.

### Designpflege

- `DESIGN.md` ist die maßgebliche aktuelle Fassung des Spieldesigns.
- Jede Änderung an Kampfregeln muss `DESIGN.md` mitändern.
- Keine stillen Änderungen an Kernregeln.
- Bestehende Datenformate bevorzugt erweitern statt Sonderfälle hart zu codieren.

### Assets

- Keine urheberrechtlich geschützten Pokémon-/Nintendo-Assets aus dem Internet laden.
- Nur abstrakte oder selbst erzeugte Platzhalter verwenden.
- Austauschbare Asset-Pfade unter `assets/` beibehalten.

### Qualität

- Größere Änderungen in funktionsfähigen Zwischenständen abschließen.
- Tests für zentrale Regeln ergänzen.
- Wenn Godot verfügbar ist, Projekt headless validieren.
- Fehler selbst analysieren und beheben; Nutzer nicht zum manuellen Debugging auffordern.
- Technische Erklärungen für den Nutzer kurz und verständlich halten.

### Architekturregeln Kampf

- 6 Teamplätze, maximal 4 aktive Monster.
- Monsteraktionen und Traineraktionen bleiben getrennte Aktionsquellen.
- Zielbestimmung ist getrennt von KI-Aktionswahl.
- Aggro-Zielpflicht zentral in einer Resolver-Funktion halten.
- Eröffnungsphase, ATB, Erholung, Verfehlen und Warten über konfigurierbare Daten/Regeln abbilden.
- Status-/Effektsystem so halten, dass spätere Mehrfachtreffer, Kanalisierung und fortlaufende Effekte möglich bleiben.
