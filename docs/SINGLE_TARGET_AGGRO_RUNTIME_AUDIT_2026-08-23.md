# Pokémon Timeflow – Runtime-Audit: Ziel-Aggro-Halbierung

Stand: 2026-08-23
Branch: `main`

## Verbindliche Regel

Wird ein Pokémon erfolgreich als einziges Ziel einer gegnerischen Einzelzielattacke getroffen, wird seine aktuelle Aggro nach vollständiger Auflösung der Attacke genau einmal mit `0,5` multipliziert.

Nicht auslösen dürfen insbesondere:

- Flächen- und Mehrzielattacken – auch dann nicht, wenn aktuell nur ein gültiges Ziel lebt.
- Verfehlte Attacken.
- Immunität, Schutz/Block oder andere fehlgeschlagene Auflösungen.
- Verbündeten- oder Selbstziele.
- Aktionen, die zwar einen Gegner referenzieren, ihn aber nicht tatsächlich treffen oder verändern.

## Zentraler Runtime-Pfad

Die finale aktive Kampfschicht `scripts/battle_demo_lab_family_refresh_v1.gd` normalisiert die Ziel-Aggro nach der vollständigen erbenden Attackenauflösung.

Die invariant gehaltenen Regeln liegen in:

- `scripts/battle/single_target_aggro_rules.gd`

Die finale Schicht verfolgt:

- die tatsächlich aufgelöste Zielregel,
- die tatsächlich aufgelösten Ziele,
- Miss-Ausgaben,
- Aggro vor der Aktion,
- den Zielzustand vor und nach der Aktion.

Dadurch gilt bei reinen Status-/Kontrollattacken nicht nur eine bestandene Genauigkeitsprobe als Erfolg. Am Ziel muss tatsächlich eine Zustandsänderung stattgefunden haben. Das verhindert falsche Halbierungen bei wirkungslosen oder nur den Anwender verändernden Aktionen.

## Geprüfte Sonderfälle

### Bitterkuss

Reine gegnerische Einzelziel-Statusattacke. Erfolgreiche Verwirrung verändert das Ziel und halbiert dessen Aggro genau einmal.

### Aussetzer

Erfolgreicher Aussetzer verändert den Zielzustand und darf halbieren. Fehlt eine geeignete zuletzt verwendete Attacke und Aussetzer schlägt wirkungslos fehl, darf keine Halbierung stattfinden.

### Mimikry / Psycho-Plus

Diese Aktionen referenzieren einen Gegner, verändern aber ausschließlich den Anwender. Sie gelten daher nicht als erfolgreicher feindlicher Treffer auf das Ziel und lösen keine Ziel-Aggro-Halbierung aus.

### Nachtnebel

Custom-Schaden ohne normalen `damage`-Mechanic-Eintrag. Die Runtime erkennt den Schadensvertrag über `aggro.from_damage`. Erfolgreicher Schaden halbiert genau einmal; Typ-Immunität nicht. Eine bereits aus historischem Sondercode erfolgte Halbierung wird nicht ein zweites Mal angewandt.

### Seher

Beim Vorbereiten findet noch kein Treffer statt und die Ziel-Aggro bleibt unverändert. Erst der spätere erfolgreiche Einschlag ist ein gegnerischer Einzelzieltreffer. Dieser historische Sonderpfad wird in der finalen Schicht auf dieselbe zentrale Regel normalisiert.

### Gegenstoß

Der automatische Gegenangriff läuft historisch außerhalb des normalen `_execute_move`-Resolvers. Nach tatsächlich verursachtem Schaden wird sein Ziel-Aggro-Ergebnis in der finalen Schicht auf dieselbe zentrale `0,5`-Regel normalisiert.

### Flächenattacken

`area = true` und `all_*`-Zielregeln werden strukturell als Fläche behandelt. Die Zahl der gerade lebenden Ziele ändert diese Klassifikation nicht. Eine Flächenattacke mit nur einem verbleibenden Ziel erhält daher niemals die Einzelziel-Aggro-Halbierung.

Dies gilt auch für Flächenattacken, die Verbündete treffen können, z. B. Erdbeben/Surfer-artige `all other`-Regeln.

## Bewusst keine Ziel-Aggro-Halbierung

Folgende Schäden sind keine neuen gegnerischen Einzelzielattacken und lösen deshalb keine zusätzliche Halbierung aus:

- Gift / schwere Vergiftung / Verbrennung und andere periodische Status-Ticks,
- Wetter- und Feldeffekt-Schaden,
- Eintritts- und Kontaktgefahren,
- Egelsamen-/Bindungs-Ticks,
- Verwirrungs-Selbstschaden,
- sonstiger indirekter Schaden ohne neuen gegnerischen Einzelzieltreffer.

## Regressionstest

`tests/single_target_aggro_rule_test.gd` deckt derzeit mindestens ab:

- Bitterkuss erfolgreich,
- normalen Einzelzielschaden,
- Miss,
- wirkungslos gescheiterten Aussetzer,
- Mimikry als reine Anwenderänderung,
- Nachtnebel Treffer,
- Nachtnebel Immunität,
- Seher Vorbereitung und späteren Einschlag,
- automatischen Gegenstoß,
- Flächenschaden mit einem und mehreren Zielen,
- `all other`-Fläche mit getroffenem Verbündeten,
- strukturelle Klassifikation der aktiven Flächenattacken.

Der zugehörige Workflow ist `.github/workflows/single-target-aggro-tests.yml`.
