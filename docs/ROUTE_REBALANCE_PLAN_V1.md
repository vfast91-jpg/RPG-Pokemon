# Demo-Route Rebalance – Umsetzungsplan V1

Stand: 2026-08-22

## Verbindlicher Branch

Ausschließlich `main`. Keine neuen Branches, kein Branch-Wechsel.

## Umsetzungsstatus

- Phase A: abgeschlossen – Sicherheitsbaseline und Regression-Sperrliste
- Phase B: abgeschlossen – Speziesfamilien und Familien-Fangraten
- Phase C: abgeschlossen – geschütztes Onboarding Etappe 1–10, dynamisches Gegnerlevel ab Etappe 11
- Phase D: abgeschlossen – normale Etappen-EP auf 50 % als Testwert
- Phase E: abgeschlossen – Fangwiese mit drei Suchen und Seltenheitsgewichtung
- Phase F: abgeschlossen – Fundstelle mit TM, Heilitem und Vitaminen
- Phase G: abgeschlossen – finaler Fünfer-Ereignispool, Boss-Umbau und Familiengewichtung normaler Gegner; Boss erst ab Etappe 11
- Phase H: abgeschlossen – alte Direct/Dangerous/+25%-Einstiegspunkte im aktiven Layer gesperrt; tiefe Altdateien bleiben nur als ungefährliche Vererbungsbasis erhalten, damit funktionierende UI-/Entwicklungslogik nicht unnötig beschädigt wird
- Phase I: automatisierte Regressionen und Integrationstest sind im Workflow eingetragen; die abschließende visuelle Godot-Spielprüfung bleibt lokal auszuführen

Aktive Szene nach dem Umbau:

- `main.tscn`
- Route: `scripts/demo_route_cleanup_v1.gd`
- Kampf: `scripts/battle_demo_route_vitamins_v1.gd`

## Phase A – Sicherheitsbaseline

Ausgangs-Commit vor diesem Plan: `df0aeba76265392dd121c6c15ca259289d1da3fe`.

Der vorhandene GitHub-Actions-Workflow `Godot Headless Tests` läuft bei Pushes auf `main` und enthält unter anderem die vorhandenen Route-, Kampf-, Entwicklungs-, TM- und Datenbank-Regressionstests sowie die neuen Rebalance-Regressionstests.

## Geschützte bestehende Systeme

Diese Systeme dürfen durch den Route-Umbau nicht nebenbei verändert werden:

- komplettes Timeflow-/ATB-System
- AP-System
- Aggro und Zielpflicht
- Typen, Effektivität und Schadenslogik
- Statussystem
- Attackenziele und KI
- individuelle Pokémon-EP-Kurven
- Level-Up-Popup vor Entwicklung
- Entwicklungen und Attackenlernen
- EP auch für Pokémon, die einen Etappenkampf begonnen haben und darin K. o. gehen
- Trainingsplatz: genau ein Pokémon, garantierter Level-Up, 15 % der neuen Max-KP als Kosten
- Viererteam und kein aktives Lagersystem
- Fangvorschau mit Sprite, Werten, Radar und Attacken
- Heilquelle heilt das gesamte Team
- Bossdarstellung und echter doppelter KP-Pool
- 90 Etappen
- Bestenliste
- TM-Kompatibilitätslogik
- Attacken-Datenbank bleibt bei diesem Route-Umbau unangetastet

## Neue Gegnerlevel-Regel

Etappen 1–10 sind als geschütztes Onboarding fest gesetzt:

- Etappe 1: 1 Gegner Lv.2
- Etappe 2: 1 Gegner Lv.3
- Etappe 3: 2 Gegner Lv.3
- Etappe 4: 2 Gegner Lv.4
- Etappe 5: 3 Gegner Lv.4
- Etappe 6: 2 Gegner Lv.5
- Etappe 7: 2 Gegner Lv.6
- Etappe 8: 3 Gegner Lv.6
- Etappe 9: 3 Gegner Lv.7
- Etappe 10: 3 Gegner Lv.8

In Etappe 1–10 gibt es keine Vierergruppe und keine dynamische Skalierung nach dem eigenen Team. Das gibt Zeit, das Kampfsystem kennenzulernen und das Team aufzubauen.

Ab Etappe 11 gilt:

`Referenzlevel = höchstes Level im eigenen Team`

Gegnerlevel nach Gruppengröße:

- 1 Gegner: Referenzlevel +5
- 2 Gegner: Referenzlevel +2
- 3 Gegner: Referenzlevel ±0
- 4 Gegner: Referenzlevel -2

Immer auf Level 1–100 begrenzen.

Die bisherigen festen Zehner-Levelplateaus entfallen vollständig.

Bei Etappe 11 erscheint einmal pro Run ein Hinweis, dass sich das Gegnerniveau ab jetzt nach dem höchstleveligen eigenen Pokémon richtet. Weitere Levelband-Hinweise entfallen.

## EP-Tempo

Level 100 bleibt die Obergrenze.

Die individuellen Pokémon-Wachstumskurven bleiben unverändert. Nur die normale Etappenkampf-EP-Menge wird zunächst als Balancing-Test auf 50 % des bisherigen Werts gesetzt.

Bosskämpfe verwenden dieselbe normale Etappenkampf-EP wie normale Etappenkämpfe. Kein 2×-Boss-EP-Bonus mehr.

## Wegereignisse

Vollständiger aktiver Pool:

1. Heilquelle
2. Fangwiese
3. Fundstelle
4. Trainingsplatz
5. Besondere Begegnung / Boss

`Direkter Pfad` und `Gefährlicher Pfad` werden nicht mehr angeboten oder ausgeführt.

Während des geschützten Einstiegs Etappe 1–10 wird die Besondere Begegnung / der Boss aus dem Pool entfernt. Pro Etappe werden drei verschiedene Ereignisse vollständig zufällig aus Heilquelle, Fangwiese, Fundstelle und Trainingsplatz gezogen.

Ab Etappe 11 werden wieder drei verschiedene Ereignisse vollständig zufällig aus allen fünf aktiven Ereignissen gezogen. Keine feste Position und keine Sonderregel, dass Slot 1 Heilquelle oder Fangwiese sein muss.

Ab Etappe 11 ergibt die gleichmäßige Gewichtung der fünf Ereignisse:

- 90 % Chance, dass mindestens Heilquelle oder Fangwiese in der Auswahl ist
- 30 % Chance, dass beide enthalten sind
- 10 % Chance, dass weder Heilquelle noch Fangwiese enthalten ist; dann besteht die Auswahl aus Fundstelle, Trainingsplatz und Boss

Die anfängliche Gewichtung bleibt gleich. Erst Tests dürfen später eine Gewichtungsänderung begründen.

## Fangwiese

Basis-Fanglevel:

`höchstes eigenes Pokémon-Level - 3`, mindestens Lv.1.

Maximal drei Pokémon-Angebote pro Fangwiese:

- Suche 1: 100 % des Basis-Fanglevels
- Suche 2: 75 %, abgerundet
- Suche 3: 50 %, abgerundet

Minimum immer Lv.1. Nach Suche 3 keine weitere Suche.

Ein gefundenes Pokémon wird nicht mehr automatisch angenommen. Der Spieler darf es ansehen, aufnehmen bzw. bei vollem Team ersetzen oder weitersuchen. Nach der dritten Ablehnung endet die Fangwiese ohne Fang. Keine +25-%-EP-Trostbelohnung mehr.

Solange andere gültige Familien vorhanden sind, wird innerhalb derselben Fangwiese keine bereits angebotene Speziesfamilie direkt erneut angeboten.

## Begegnungshäufigkeit nach Speziesfamilie

Grundwert einer Familie:

`Familien-Fangrate = Durchschnitt der Fangraten aller Mitglieder der Entwicklungsfamilie`

Dieser vorberechnete Familienwert wird separat in den Runtime-Daten gehalten; die originale Fangrate jeder einzelnen Spezies bleibt unverändert bestehen.

Die aktualisierte Tabellenquelle enthält außerdem `Speziesfamilien-ID` und `Familien-Fangrate`.

Normale Gegner und Bosse verwenden als Grund-Begegnungsgewicht:

`Gewicht = Familien-Fangrate`

Gewichtung der Fangwiesen-Suchen:

- Suche 1: `Familien-Fangrate ^ 1.0`
- Suche 2: `Familien-Fangrate ^ 0.5`
- Suche 3: `Familien-Fangrate ^ 0.25`

Dadurch steigen bei späteren Suchen die relativen Chancen schwerer fangbarer / seltener Familien, ohne sie zu garantieren.

Später kann ein Landschafts-/Typfaktor multiplikativ ergänzt werden:

`Endgewicht = Suchgewicht × Landschaftsfaktor`

Der Landschaftsfaktor wird in diesem Umbau noch nicht implementiert.

## Fundstelle

Die bisherige `TM-Fundstelle` wird zur `Fundstelle`.

Sie bietet grundsätzlich sechs Alternativen; genau eine darf gewählt werden:

- Slots 1–3: bis zu drei zufällige, für das aktuelle Team tatsächlich nutzbare TMs
- Slot 4: ein zum Routenfortschritt passendes Heilitem, sofort einsetzbar, nicht einlagerbar
- Slots 5–6: zwei verschiedene zufällige, noch sinnvoll nutzbare Vitamine

Falls weniger als drei noch nutzbare TMs existieren, werden keine künstlich unbrauchbaren TMs erzeugt; die Fundstelle zeigt die tatsächlich vorhandenen kompatiblen TM-Angebote plus Heilitem/Vitamine.

Heilitem-Teststaffel:

- Etappe 1–20: Trank, +20 KP
- Etappe 21–40: Supertrank, +50 KP
- Etappe 41–60: Hypertrank, +120 KP
- Etappe 61–90: Top-Trank, volle KP

Heilitems können keine kampfunfähigen Pokémon wiederbeleben.

Vitamine:

- Protein → Angriff
- Eisen → Verteidigung
- Kalzium → Status
- Carbon → Initiative
- Zink → KP

Balancing-Testwert: **+1 permanenter Endwertpunkt** im jeweiligen Attribut pro Anwendung. Pro individuellem Pokémon und Attribut gilt ein Cap von **+10 Vitaminpunkten**. Der Bonus wird individuell am Pokémon gespeichert, im Kampf und in der Team-/Radaransicht berücksichtigt und bleibt bei Level-Up oder Entwicklung erhalten. Zink erhöht Max-KP; bei einem lebenden Pokémon steigt beim Einnehmen auch der aktuelle KP-Wert um denselben Punkt, bei einem K.-o.-Pokémon erfolgt keine Wiederbelebung.

Die bisherige Alternative `keine TM → +25 % EP` entfällt.

## Boss / Besondere Begegnung

Die Besondere Begegnung ist erst ab Etappe 11 im Wegpool verfügbar.

- Bosslevel = höchstes eigenes Pokémon-Level +5, maximal Lv.100
- echter doppelter KP-Pool bleibt
- normale Etappenkampf-EP, kein Bonusmultiplikator
- Boss-Spezies nutzt dieselbe Familien-Fangraten-Grundgewichtung wie normale Gegner
- nach vollständiger Abwicklung von EP, Level-Ups und Entwicklungen folgt eine vollständige Fundstelle als Zusatzbelohnung
- nach der Boss-Fundstelle ist die Etappe beendet; es startet kein zweiter Etappenkampf

Die bestehende sichere Sequenzidee wird weiterverwendet: erst Kampf, dann EP/Level-Up/Entwicklung, danach Belohnung.

## Umsetzungsphasen

A. Sicherheitsbaseline und Regression-Sperrliste
B. Datenbasis für Speziesfamilie und Familien-Fangrate
C. Geschütztes Onboarding Etappe 1–10, danach dynamisches Gegnerscaling und Etappe-11-Hinweis
D. EP-Tempo und zentrale Etappen-EP-Quelle
E. Fangwiese mit drei Suchen und Seltenheitsgewichtung
F. Fundstelle mit TM, Heilitem und Vitaminen
G. Spezialereignisse: Direkter/Gefährlicher Pfad entfernen, Boss umbauen und erst ab Etappe 11 erlauben
H. Verwaiste Altlogik kontrolliert absichern
I. Gesamttests und visuelle Godot-Prüfung

Nach jeder Phase muss der Stand wieder funktionsfähig sein. Wenn eine Regression außerhalb des gerade geänderten Systems auftaucht, wird sie zuerst behoben, bevor die nächste Phase beginnt.
