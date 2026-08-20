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
- Ein normaler neuer Run darf den Pokédex **nicht zurücksetzen**.
- Ein erfolgreicher Fang wird auf zwei Ebenen gespeichert:
  1. Die **konkret gefangene Form** wird über ihre stabile `species_id` festgehalten, damit ein späterer detaillierter Pokédex weiterhin unterscheiden kann, ob z. B. tatsächlich Tauboga oder Taubsi gefangen wurde.
  2. Gleichzeitig wird die **gesamte Entwicklungslinie** dauerhaft für den Run-übergreifenden Fortschritt freigeschaltet.
- Für die spätere Start-Pokémon-Auswahl eines neuen Runs zählt immer die **niedrigste bekannte Form der freigeschalteten Entwicklungslinie**, weil neue Runs mit Low-Level-Pokémon beginnen.
- Beispiel: Wird **Tauboga** oder **Tauboss** gefangen, wird die **Taubsi-Linie** freigeschaltet. Ein späterer neuer Run bietet daraus **Taubsi**, nicht Tauboga oder Tauboss, als mögliche Startform an.
- Der Fang einer höheren Entwicklung markiert die niedrigere Form **nicht fälschlich als konkret gefangen**. Die Unterscheidung zwischen konkreter Pokédex-Form und freigeschalteter Entwicklungslinie bleibt erhalten.
- Sobald ein Fangsystem einen erfolgreichen Fang bestätigt, muss es `MetaProgression.record_caught(species_id)` aufrufen. Die Zuordnung zur Entwicklungslinie erfolgt automatisch über `data/rules/evolution_chains.json`.
- Optional kann bereits bei einer Begegnung `MetaProgression.record_seen(species_id)` aufgerufen werden, damit später zwischen „gesehen“ und „gefangen“ unterschieden werden kann.
- Ob der Spieler aus den freigeschalteten Entwicklungslinien später frei auswählt, eine Zufallsauswahl bekommt oder eine andere Startregel verwendet, ist noch **nicht festgelegt**. Die Persistenz darf diese spätere Designentscheidung nicht vorwegnehmen.
- Die aktuelle Kampf-/Erkundungsdemo benötigt noch keine Pokédex-Oberfläche und muss durch diese Vorbereitung spielerisch nicht verändert werden.

Die technische Grundlage liegt in `scripts/meta_progression.gd` und wird als Autoload `MetaProgression` geladen. Der persistente Speicher wird außerhalb der Projektdateien unter `user://meta_progression.json` angelegt. Ein späterer Run-Speicher muss separat geführt werden. Ältere Meta-Spielstände werden beim Laden automatisch so migriert, dass bereits konkret gefangene Spezies die passende Entwicklungslinie freischalten.
