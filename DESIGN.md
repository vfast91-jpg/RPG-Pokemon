# RPG Pokémon – aktuelle Designregeln

Dieses Dokument hält verbindliche Spielregeln fest, die bei späteren Änderungen nicht stillschweigend überschrieben werden dürfen.

## Entwicklung

- Entwicklungen können **nicht verhindert** werden.
- Eine Level-Entwicklung erfolgt **automatisch und verpflichtend**, sobald das erforderliche Level erreicht ist.
- Alte Datenfelder wie `prevent_evolution: true` oder `evolution_optional: true` sind überholt und dürfen die aktuelle Regel nicht mehr verändern.
- Zufällig erzeugte wilde oder gegnerische Pokémon müssen immer die Entwicklungsstufe besitzen, die zu ihrem Level gehört.
- Beispiel Raupy-Reihe:
  - bis Level 6: Raupy
  - Level 7–9: Safcon
  - ab Level 10: Smettbo
- Fehlt für eine verpflichtende Entwicklungsstufe noch ein vollständiger Spieldatensatz, darf die vorherige Form nicht mit einem unpassenden Level erzeugt werden. Die betreffende Entwicklungsreihe wird für solche generierten Begegnungen vorübergehend ausgeschlossen.
- Sobald die Zielspeziesdaten vorhanden sind, löst der zentrale Entwicklungsresolver automatisch auf die korrekte Form auf.

Die technische Quelle dieser Regel ist `data/rules/evolution_chains.json`; die Auflösung erfolgt zentral über `scripts/evolution_resolver.gd`.
