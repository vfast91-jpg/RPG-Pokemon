# Statuswert-Migration V1

Dieses Dokument ist der verbindliche Entscheidungsschritt zwischen dem abgeschlossenen Attacken-Audit und der eigentlichen Daten-/Runtime-Migration.

**Wichtig:** Dieser Schritt schaltet noch keine neue Runtime-Logik frei. Die Formeln sind festgelegt; die 17 betroffenen Attacken werden erst im naechsten Schritt in den aktiven Attackendaten und anschliessend in der zentralen Runtime migriert.

## Grundkurve

`R = Status / (75 + Status)`

Status 75 ergibt `R = 0,5` und dient als Kalibrierungspunkt. Dadurch bleiben bisherige Referenzwirkungen bei einem guten Statusnutzer ungefaehr erhalten, waehrend niedrigere und hoehere Statuswerte sinnvoll unterscheiden.

## Zentrale Formeln

- Max-KP-Heilung: `Heilung = Max-KP × min(1, Gewicht × R)`
- Schadensgebundener Drain: `Heilung = tatsaechlicher KP-Schaden × min(1, Gewicht × R)`
- Schutz/Reduktion: `eingehender Multiplikator = (1 − R) ^ Gewicht`
- Additiver Schadensbonus: `Multiplikator = 1 + Gewicht × R`
- Volltreffer-Support: `Bonus = 100 × Gewicht × R Prozentpunkte`
- ATB-Startfortschritt: `Startfortschritt = Gewicht × R`
- ATB-Beschleunigung: `naechster Zyklus × (1 − R) ^ Gewicht`

## Festgelegte Migrationen

### Drain

- Ableithieb, Bezirzer, Blutsauger, Gigasauger und Raub: Gewicht 1,0 → bei Status 75 weiterhin 50 % des tatsaechlichen Schadens als Heilung.
- Diebeskuss: Gewicht 1,5 → bei Status 75 weiterhin 75 %; Heilung ist auf 100 % des tatsaechlichen Schadens begrenzt.
- Egelsamen: periodischer Schaden bleibt fest `1/8 Max-KP` des Ziels. Nur die Rueckheilung skaliert, Gewicht 2,0. `R` wird beim erfolgreichen Anwenden gespeichert.

### Direkte Heilung

- Synthese: Gewicht 1,0.
- Ruheort: Gewicht 1,0; temporaerer Flug-Typverlust bleibt unveraendert.
- Pollenknödel: Verbündetenmodus Gewicht 1,0; Gegnermodus bleibt normaler Schaden.
- Verzehrer: 1/2/3 Horter-Ladungen verwenden Gewicht 0,5 / 1,0 / 2,0. Bei Status 75 ergeben sich damit weiterhin 25 / 50 / 100 % Max-KP.

### Schutz, Terrain und ATB

- Reflektor: physischer Schaden gegen das Team wird mit `1 − R` multipliziert; damit dieselbe zentrale Logik wie Lichtschild.
- Elektrofeld: Elektro-Schadensmultiplikator `1 + 0,6R`; Schlafschutz bleibt binaer. `R` wird bei Terrainaktivierung gespeichert.
- Grasfeld: Pflanzen-Schadensmultiplikator `1 + 0,6R`; jeder der drei Heilpulse heilt `0,125R × Max-KP`. `R` wird bei Terrainaktivierung gespeichert.
- Grasrutsche: im Grasfeld und am Boden startet die naechste ATB-Leiste nach erfolgreichem Treffer bei `50R %`.
- Voltwechsel: eigene Aggro bleibt nach erfolgreichem Treffer fest `×0,55`; der naechste eigene ATB-Zyklus wird `×(1 − R)^0,5` gerechnet. Bei Status 75 entspricht das ungefaehr dem bisherigen `×0,70`.

### Drachenjubel

Drachenjubel wird von diskreten attackenspezifischen Volltrefferstufen auf die bereits etablierte statuswertbasierte Volltreffer-Logik uebersetzt:

- Nicht-Drachen: `+50R` Prozentpunkte Volltrefferchance.
- Drachen: `+100R` Prozentpunkte Volltrefferchance.
- Dauer: drei eigene Aktionen des jeweiligen Ziels.
- Keine Stapelung bzw. kein Refresh mit Drachenjubel oder Energiefokus.
- Finale Volltrefferchance maximal 100 %.

## Bewusste Sonderregeln – keine Migration

Psychoschock und Schleuder sind **keine Fehler**. Beide wurden bewusst so designt, dass direkter Schaden den Statuswert als offensiven Wert benutzt. Sie bleiben unveraendert.

Weitere bewusste Schadens-/Regel-Ausnahmen bleiben ebenfalls erhalten:

- Body Press → aktuelle Verteidigung des Anwenders als offensiver Wert.
- Schmarotzer → aktueller Angriff des Ziels.
- Nachtnebel → fester Levelschaden.
- Notsituation → feste KP-Angleichung.
- Superzahn → fester Anteil aktueller Ziel-KP.
- Leidteiler → KP-Gleichverteilung als Regeloperation.
- Erholung → feste Vollheilung als Gegenleistung fuer erzwungenen Schlaf.
- Feuerwirbel, Sandgrab, Whirlpool und Wickel → zentrale Binding-Regel; periodischer Schaden bleibt fest und wird nicht Status-skaliert.
- Feuer-, Pflanzen- und Wassersaeulen → zentrale Team-Kombomechanik bleibt fest und statusunabhaengig.

## Ergebnis dieses Schrittes

- 17 Attacken sind mit konkreter Formel **bereit fuer die Datenmigration**.
- 16 Faelle sind **bewusste Sonderregeln** und bleiben unveraendert.
- 0 offene Konflikte.

Technischer maschinenlesbarer Vertrag: `data/rules/status_effect_migration_v1.json`.
