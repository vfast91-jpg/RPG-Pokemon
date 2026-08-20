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

## Pokédex und run-übergreifender Fortschritt

- Der Pokédex ist **Meta-Fortschritt** und ausdrücklich vom Speicherstand eines einzelnen Runs getrennt.
- Pokémon werden im Pokédex über ihre stabile `species_id` gespeichert, nicht über ein konkretes individuelles Pokémon-Objekt.
- Sobald ein Fangsystem einen erfolgreichen Fang bestätigt, muss es `MetaProgression.record_caught(species_id)` aufrufen.
- Optional kann bereits bei einer Begegnung `MetaProgression.record_seen(species_id)` aufgerufen werden, damit später zwischen „gesehen“ und „gefangen“ unterschieden werden kann.
- Ein normaler neuer Run darf den Pokédex **nicht zurücksetzen**.
- Jede mindestens einmal gefangene Spezies gehört zum dauerhaft freigeschalteten Pool für einen späteren Run-Start.
- Ob der Spieler aus diesem Pool frei auswählt, eine Zufallsauswahl bekommt oder eine andere Startregel verwendet, ist noch **nicht festgelegt**. Die Persistenz darf diese spätere Designentscheidung nicht vorwegnehmen.
- Die aktuelle Kampf-/Erkundungsdemo benötigt noch keine Pokédex-Oberfläche und muss durch diese Vorbereitung spielerisch nicht verändert werden.

Die technische Grundlage liegt in `scripts/meta_progression.gd` und wird als Autoload `MetaProgression` geladen. Der persistente Speicher wird außerhalb der Projektdateien unter `user://meta_progression.json` angelegt. Ein späterer Run-Speicher muss separat geführt werden.
