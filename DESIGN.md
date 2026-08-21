# RPG Pokémon – aktuelle Designregeln

Dieses Dokument hält verbindliche Spielregeln fest, die bei späteren Änderungen nicht stillschweigend überschrieben werden dürfen.

## Entwicklung

- Entwicklungen können **nicht verhindert** werden.
- Eine lineare Level-Entwicklung mit genau einem gültigen Ziel erfolgt **automatisch und verpflichtend**, sobald das erforderliche Level erreicht ist.
- Gibt es bei einer fälligen Entwicklung **mehrere gültige Ziel-Spezies**, darf das Spiel **niemals automatisch, zufällig oder nach Listenreihenfolge** eine davon wählen.
- Stattdessen zeigt das Spiel dem Spieler **alle definierten Entwicklungsziele** an. Der Spieler wählt bewusst die gewünschte Form; erst danach wird die Entwicklung angewendet.
- Diese Verzweigungsregel ist allgemeingültig und darf nicht für einzelne Pokémon hartcodiert werden. Sie ist unter anderem für Familien wie Evoli, Rabauz, Duflor, Quaputzi und Sichlor vorgesehen.
- Die Anzahl der Ziele ist nicht fest begrenzt: dieselbe Logik muss zwei, drei oder auch deutlich mehr Entwicklungsformen anzeigen können.
- Alte Datenfelder wie `prevent_evolution: true` oder `evolution_optional: true` sind überholt und dürfen die aktuelle Regel nicht mehr verändern.
- Zufällig erzeugte wilde oder gegnerische Pokémon müssen immer die Entwicklungsstufe besitzen, die zu ihrem Level gehört.
- Automatisch erzeugte Pokémon dürfen bei einer Verzweigung **keinen stillen Zufallszweig** nehmen. Solange für generierte Begegnungen keine ausdrücklich definierte Branch-Regel existiert, wird eine auf diesem Level nicht eindeutig auflösbare Familie aus der Erzeugung ausgeschlossen.
- Fehlt für eine definierte Entwicklungsstufe noch ein vollständiger Spieldatensatz, darf die vorherige Form nicht mit einem unpassenden Level erzeugt werden. Ein fehlendes Verzweigungsziel wird in einer Spielerwahl als nicht verfügbar behandelt und kann nicht ausgewählt werden.
- Sobald die Zielspeziesdaten vorhanden sind, kann der zentrale Entwicklungsresolver sie ohne Pokémon-spezifische Zusatzlogik verwenden.

### Datenformat

Lineare Entwicklung bleibt kompatibel mit dem bisherigen Format:

```json
"caterpie": {"target": "metapod", "level": 7}
```

Eine Verzweigung wird datengetrieben über `choices` beschrieben:

```json
"example_base": {
  "choices": [
    {"target": "example_form_a", "level": 20},
    {"target": "example_form_b", "level": 20},
    {"target": "example_form_c", "level": 20}
  ]
}
```

Alternativ darf ein Spezies-Datenpaket dieselbe Struktur unter `evolution.choices` liefern. Der Resolver akzeptiert außerdem ein Array in `evolution.evolves_into`, damit spätere Datenimporte nicht unnötig starr sind.

Die technische Quelle dieser Regel ist `data/rules/evolution_chains.json`; die Auflösung erfolgt zentral über `scripts/evolution_resolver.gd`. `scripts/battle_demo_forced_evolution.gd` stellt die Resolver-Funktionen für die Route bereit. `scripts/demo_route_evolution_ui.gd` besitzt den generischen Auswahlbildschirm und darf selbst keine Ziel-Spezies erfinden oder auswählen.

## Pokédex und run-übergreifender Fortschritt

- Der Pokédex ist **Meta-Fortschritt** und ausdrücklich vom Speicherstand eines einzelnen Runs getrennt.
- Ein normaler neuer Run darf den Pokédex **nicht zurücksetzen**.
- Ein erfolgreicher Fang wird auf zwei Ebenen gespeichert:
  1. Die **konkret gefangene Form** wird über ihre stabile `species_id` festgehalten, damit ein späterer detaillierter Pokédex weiterhin unterscheiden kann, ob z. B. tatsächlich Tauboga oder Taubsi gefangen wurde.
  2. Gleichzeitig wird die **gesamte Entwicklungslinie** dauerhaft für den Run-übergreifenden Fortschritt freigeschaltet.
- Für die spätere Start-Pokémon-Auswahl eines neuen Runs zählt immer die **niedrigste bekannte Form der freigeschalteten Entwicklungslinie**, weil neue Runs mit Low-Level-Pokémon beginnen.
- Beispiel: Wird **Tauboga** oder **Tauboss** gefangen, wird die **Taubsi-Linie** freigeschaltet. Ein späterer neuer Run bietet daraus **Taubsi**, nicht Tauboga oder Tauboss, als mögliche Startform an.
- Verzweigte Entwicklungen gehören weiterhin zu derselben Ursprungsfamilie: Wird später beispielsweise eine Endform einer verzweigten Linie gefangen, muss der Meta-Fortschritt bis zur gemeinsamen niedrigsten bekannten Ausgangsform zurückauflösen können.
- Der Fang einer höheren Entwicklung markiert die niedrigere Form **nicht fälschlich als konkret gefangen**. Die Unterscheidung zwischen konkreter Pokédex-Form und freigeschalteter Entwicklungslinie bleibt erhalten.
- Sobald ein Fangsystem einen erfolgreichen Fang bestätigt, muss es `MetaProgression.record_caught(species_id)` aufrufen. Die Zuordnung zur Entwicklungslinie erfolgt automatisch über `data/rules/evolution_chains.json`.
- Optional kann bereits bei einer Begegnung `MetaProgression.record_seen(species_id)` aufgerufen werden, damit später zwischen „gesehen“ und „gefangen“ unterschieden werden kann.
- Ob der Spieler aus den freigeschalteten Entwicklungslinien später frei auswählt, eine Zufallsauswahl bekommt oder eine andere Startregel verwendet, ist noch **nicht festgelegt**. Die Persistenz darf diese spätere Designentscheidung nicht vorwegnehmen.
- Die aktuelle Kampf-/Erkundungsdemo benötigt noch keine Pokédex-Oberfläche und muss durch diese Vorbereitung spielerisch nicht verändert werden.

Die technische Grundlage liegt in `scripts/meta_progression.gd` und wird als Autoload `MetaProgression` geladen. Der persistente Speicher wird außerhalb der Projektdateien unter `user://meta_progression.json` angelegt. Ein späterer Run-Speicher muss separat geführt werden. Ältere Meta-Spielstände werden beim Laden automatisch so migriert, dass bereits konkret gefangene Spezies die passende Entwicklungslinie freischalten.

## Zentrale Status-Skalierung

Der Kampfwert **Status** (intern aus Kompatibilitätsgründen teilweise noch `special`) bestimmt weiterhin die Stärke von Buffs, Debuffs, Kontrolle, Heilung und unterstützenden Effekten. Die alte lineare Regel `Status = Prozent` mit harten Caps ist für Status-basierte Attacken überholt.

Die zentrale Kurve lautet:

`R = Status / (75 + Status)`

Damit bleibt jeder zusätzliche endliche Statuspunkt wirksam. Beispiele für `100 × R`: Status 25 = 25 %, Status 50 = 40 %, Status 75 = 50 %, Status 100 ≈ 57,1 %, Status 200 ≈ 72,7 %, Status 300 = 80 %.

Move-Gewichtungen wie 1×, 2× oder 3× bleiben erhalten und werden **nach** der Kurve angewendet:

- Verstärkung oder Verlangsamung: `Multiplikator = 1 + Gewicht × R`
- Abschwächung oder Beschleunigung: `Multiplikator = (1 − R) ^ Gewicht`
- Natürlich auf 100 % begrenzte Wirkungen wie Heilung, Lichtschild und der Energiefokus-Bonus verwenden `100 × R` Prozent bzw. Prozentpunkte.

Damit entspricht eine normale 1×-Senkung exakt der Kurve: Status 25 senkt um 25 %, Status 50 um 40 %, Status 100 um etwa 57,1 %. Bei 2×-/3×-Attacken wird der verbleibende Anteil potenziert; dadurch werden sie stärker, ohne bei einem endlichen Statuswert negative Werte oder einen künstlichen harten Cap zu erzeugen.

Dadurch entstehen bei hohen Statuswerten keine negativen ATB-Zeiten, keine Schadensreduktion über 100 % und kein künstlicher Endpunkt bei Status 25, 50 oder 100. Heuler, Rutenschlag, Panzerschutz, Fadenschuss, Agilität, Charme, Falterreigen, Einrollen und alle anderen Mechaniken mit `multiplier_from_special` verwenden dieselbe zentrale Kurvenlogik.

Technische Referenz: `data/rules/status_scaling.json`, `scripts/battle_demo_status_softcaps.gd` und die finale Verfeinerung `scripts/battle_demo_status_curve_final.gd`.

## Wetter als eigenständiger globaler Kampfzustand

**Regentanz** und **Sonnentag** skalieren nicht mit Status/Spezial. Die Attacken besitzen nur noch eine Aufgabe:

- Regentanz → aktiviert `weather_id = rain`
- Sonnentag → aktiviert `weather_id = sun`

Die Attacke selbst bestimmt weder Wetterstärke noch Wetterwirkung noch die zentrale Wetterdauer. Diese Eigenschaften liegen ausschließlich in `data/rules/weather_rules.json` und werden durch `BattleWeatherState` verwaltet. Es kann gleichzeitig nur ein globales Wetter aktiv sein; ein neu aktiviertes Wetter ersetzt ein anderes aktives Wetter.

Das Architekturprinzip lautet: **Quelle → aktiviert Wetter-ID → Wettersystem übernimmt.** Dadurch können später Fähigkeiten, Items, Gebiete oder Bossmechaniken dasselbe Wetter auslösen, ohne Regentanz oder Sonnentag simulieren zu müssen.
