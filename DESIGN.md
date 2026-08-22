# RPG Pokémon – aktuelle Designregeln

Dieses Dokument hält verbindliche Spielregeln fest, die bei späteren Änderungen nicht stillschweigend überschrieben werden dürfen.

## Aggro-Halbierung bei erfolgreichen Einzelzielattacken

Wird ein Pokémon von einer **gegnerischen Einzelzielattacke erfolgreich getroffen**, wird seine aktuelle Aggro **nach vollständiger Auflösung der gesamten Attacke genau einmal halbiert**:

`Aggro_neu = Aggro_alt × 0.5`

Diese Regel gilt unabhängig davon, ob die Attacke Schaden verursacht oder eine reine Status-, Debuff- oder Kontrollattacke ist. Die Halbierung darf insbesondere **nicht** an tatsächlich verursachten KP-Schaden gekoppelt werden.

- Mehrfachtreffer gegen dasselbe Einzelziel halbieren die Aggro nur einmal nach der vollständigen Attacke.
- Flächen- und Mehrzielattacken lösen keine Aggro-Halbierung aus, auch wenn beim Ausführen nur noch ein gültiges Ziel vorhanden ist.
- Verfehlen, vollständige Abwehr oder eine Immunität ohne erfolgreichen Treffer lösen keine Halbierung aus.
- Die Regel ist zentral umzusetzen und darf nicht pro Attacke hartkodiert werden.

Kanonische Detailquellen: `docs/RPG_POKEMON_KAMPFREGELN_MASTER_V5.md` und `docs/RPG_POKEMON_ATTACKEN_DESIGN_GUIDE_V5.md`.

## Hornliu-, Kokuna- und Bibor-Maschinen

Für die frühen Käferfamilien gilt eine bewusste Pokémon-Timeflow-Harmonisierung der Maschinen-Kompatibilität:

- Raupy: **Elektronetz**
- Hornliu: **Elektronetz**
- Safcon: **Elektronetz + Eisenabwehr**
- Kokuna: **Elektronetz + Eisenabwehr**

Die offizielle Referenz-/Fallback-Quelle der jeweiligen Spezies bleibt dokumentiert; diese kleine Timeflow-Ergänzung ist eine bewusste spielerische Harmonisierung und keine Behauptung über die offizielle TM-Liste des Fallback-Spiels.

Bibor verwendet für seine offizielle Maschinenliste den dokumentierten BDSP-Fallback. Die zuvor fehlenden Maschinenattacken **Gegenstoß, Blitz, Kreuzschere, Angeberei, Zerschneider, Auflockern und Zertrümmerer** sind im aktiven Kampfsystem implementiert.

Für diese Attacken gelten insbesondere folgende Timeflow-Regeln:

- **Gegenstoß** ist eine Reaktionshaltung mit drei Ladungen. Ein erfolgreicher gegnerischer Schadensangriff, der tatsächlich KP-Schaden verursacht, verbraucht höchstens eine Ladung und löst sofort einen automatisch treffenden physischen Unlicht-Gegenangriff mit Stärke 35 aus. Mehrfachtreffer und Flächenattacken verbrauchen pro ausgeführter Attacke höchstens eine Ladung. Verfehlen, Schutz oder 0 tatsächlicher KP-Schaden verbrauchen keine Ladung. Gegenreaktionen lösen keine weiteren Gegenreaktionen aus. Ein erneuter Einsatz setzt die Haltung auf drei Ladungen zurück.
- **Angeberei** erlaubt dem Spieler als Ziel entweder den Gegner mit höchster Aggro oder ein anderes aktives verbündetes Pokémon; Selbstziel ist ausgeschlossen. Die Trefferprüfung gilt für beide Zielarten. Bei Erfolg werden Verwirrung und der starke, drei eigene Aktionen dauernde Angriffsbonus auf dasselbe Ziel angewendet.
- **Auflockern** trifft immer, erhöht für drei eigene Aktionen die Treffbarkeit des gewählten Ziels und entfernt Eintrittsgefahren auf beiden Seiten sowie gegnerische Team-Barrieren und aktives Terrain. Schutzschild, Wetter, Hauptstatus, Egelsamen und Bindung werden nicht entfernt.
- **Blitz** verwendet den zentralen Genauigkeits-Debuff für drei eigene Aktionen des Ziels.
- **Kreuzschere** und **Zerschneider** sind reine Schadensattacken ohne zusätzliche Kampfwirkung.
- **Zertrümmerer** besitzt nach erfolgreichem Treffer eine 50-%-Chance auf den zentralen Verteidigungsdebuff für drei eigene Aktionen des Ziels.

Technische Referenz: `data/gen1_moves_runtime_v3_14_beedrill_family_tms.json`, `data/gen1_species_v3_weedle_tm_override.json`, `scripts/battle_demo_beedrill_family.gd` und `tests/beedrill_family_tm_mechanics_test.gd`.

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

Der Kampfwert **Status** (intern aus Kompatibilitätsgründen teilweise noch `special`) ist der zentrale Wirkungswert für **quantitativ skalierbare taktische Wirkungskomponenten jenseits des direkten Attackenschadens**.

### Verbindliche Zuständigkeit pro Wirkungskomponente

Die Skalierung wird nicht nach der Kategorie der gesamten Attacke entschieden, sondern **für jede Wirkungskomponente einzeln**:

- direkter KP-Schaden einer Attacke → **Angriff**
- quantitativ skalierbare nicht-schädigende Wirkung → grundsätzlich **Statuswert**
- feste, binäre oder zentral anderweitig geregelte Mechanik → keine automatische Status-Skalierung

Damit kann eine Schadensattacke gleichzeitig Angriff und Status verwenden. Bei einer Drain-Attacke wie Absorber oder Gigasauger wird beispielsweise der verursachte Schaden über Angriff berechnet; die skalierbare Rückheilung ist eine eigene Statuswert-Komponente.

Typische Statuswert-Komponenten sind Buffs, Debuffs, skalierbare Kontrolle, Heilung, Drain-Rückheilung, Schutz/Barrieren, Genauigkeitsmanipulation, ATB-Manipulation und andere quantitativ skalierbare Supportwirkungen.

Nicht automatisch Statuswert-basiert sind insbesondere:

- die bloße Anwendung eines standardisierten Hauptstatuszustands wie Paralyse, Schlaf, Gift oder Verbrennung;
- feste Regelzustände wie Verhöhner, Zugabe oder Aussetzer;
- Schutzschild als binärer Block der nächsten passenden Attacke;
- Feldgefahren und andere feste Kampffeldregeln;
- standardisierter periodischer Schaden eines bestehenden Hauptstatuszustands;
- Zurückschrecken, weil dessen zentrale Wirkung fest definiert ist;
- Wetteraktivierung, weil Wetterstärke und Wetterdauer ausschließlich im zentralen Wettersystem liegen.

Eine ausdrücklich definierte zentrale Sonderregel hat immer Vorrang. Einzelne Attacken dürfen keine konkurrierenden Statusformeln hartkodieren.

Für Drain-Attacken ist damit bereits verbindlich festgelegt: **Schaden = Angriff, Rückheilung = Statuswert**. Die gemeinsame numerische Drain-Heilungsformel wird vor der Bestandsmigration einmal zentral kalibriert; bis dahin wird keine Drain-Attacke mit einer willkürlichen Einzel-Formel umgestellt.

Die alte lineare Regel `Status = Prozent` mit harten Caps ist für Status-basierte Attacken überholt.

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

## Zurückschrecken

**Zurückschrecken ist ein fester zentraler Timeflow-Kontrolleffekt.** Die einzelne Attacke definiert nur ihre Chance auf Zurückschrecken.

Wenn Zurückschrecken auslöst:

- wird die **aktuell gefüllte Aktionsleiste des betroffenen Ziels sofort auf 0 % gesetzt**;
- gibt es **keinen** festen Rückwurf um 25 %, keinen anderen Teil-Rückwurf und keine Skalierung der Rückwurfstärke;
- verändert der Kampfwert Status die Stärke dieses Resets nicht;
- verändert ein Typ-/Statusbonus die Stärke dieses Resets nicht.

Historische Datenfelder wie `amount: 0.25` bei älteren Attackenpaketen sind Legacy-Metadaten und dürfen die Runtime nicht mehr beeinflussen. Für neue Zurückschrecken-Effekte reicht mechanisch die Proc-Chance; die Wirkung selbst kommt ausschließlich aus der zentralen Regel.

Jede Spieleranzeige muss den Effekt selbst erklären. Zulässige Formulierung ist zum Beispiel: **„30 % Chance auf Zurückschrecken: Aktionsleiste auf 0 %“**. Eine Anzeige wie „Aktionsleiste −25 %“ ist falsch.

Technische Referenz: `scripts/battle/flinch_rules.gd`, `scripts/battle/move_effect_registry.gd`, `scripts/battle/move_presenter.gd` und die aktive finale Kampfschicht `scripts/battle_demo_caterpie_family_ui.gd`.

## Wetter als eigenständiger globaler Kampfzustand

**Regentanz** und **Sonnentag** skalieren nicht mit Status/Spezial. Die Attacken besitzen nur noch eine Aufgabe:

- Regentanz → aktiviert `weather_id = rain`
- Sonnentag → aktiviert `weather_id = sun`

Die Attacke selbst bestimmt weder Wetterstärke noch Wetterwirkung noch die zentrale Wetterdauer. Diese Eigenschaften liegen ausschließlich in `data/rules/weather_rules.json` und werden durch `BattleWeatherState` verwaltet. Es kann gleichzeitig nur ein globales Wetter aktiv sein; ein neu aktiviertes anderes Wetter ersetzt das aktive Wetter sofort.

Für normales Timeflow-Wetter gilt verbindlich:

- Ein Wetter besitzt **einen einzigen kontinuierlichen Zeitbalken**, keinen Runden- oder Anwender-Aktionszähler.
- Die normale Wetterdauer beträgt **50 Sekunden aktive Kampfzeit**.
- Während der Kampf wegen einer Spielerentscheidung/Aktionsauswahl pausiert ist, pausiert auch die Wetterzeit.
- Die Wetterdauer ist vollständig unabhängig von Geschwindigkeit, AP, ATB und Aktionen des auslösenden Pokémon.
- Wird ein **anderes** Wetter aktiviert, ersetzt es das bisherige sofort und beginnt mit seiner vollständigen eigenen Dauer.
- Ist dasselbe Wetter bereits aktiv, kann es **nicht erneut ausgelöst, erneuert oder auf 50 Sekunden zurückgesetzt** werden. Seine aktuelle Restdauer bleibt unverändert.
- Wetterattacken enthalten deshalb selbst nur die `weather_id`; Dauer und Wirkung dürfen nicht wieder in Regentanz, Sonnentag oder andere Wetterquellen hineinkopiert werden.
- Im Kampf-HUD steht die Wetteranzeige zentral **direkt unter dem TYPEN-Button**: Wettername/Emoji und darunter der einzelne kontinuierlich leer laufende Wetterbalken.

Das Architekturprinzip lautet: **Quelle → aktiviert Wetter-ID → Wettersystem übernimmt.** Dadurch können später Fähigkeiten, Items, Gebiete oder Bossmechaniken dasselbe Wetter auslösen, ohne Regentanz oder Sonnentag simulieren zu müssen.

Technische Referenz: `data/rules/weather_rules.json`, `scripts/battle/weather_state.gd` und die aktive UI-/Runtime-Schicht `scripts/battle_demo_timeflow_weather.gd`.