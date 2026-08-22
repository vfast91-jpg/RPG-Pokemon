# Demo-Route Rebalance – Umsetzungsplan V1

Stand: 2026-08-22

## Verbindlicher Branch

Ausschließlich `main`. Keine neuen Branches, kein Branch-Wechsel.

## Phase A – Sicherheitsbaseline

Ausgangs-Commit vor diesem Plan: `df0aeba76265392dd121c6c15ca259289d1da3fe`.

Aktive Szene auf `main`:

- `main.tscn`
- Route: `scripts/demo_route_levelup_evolution_order_fix.gd`
- Kampf: `scripts/battle_demo_route_result_guard.gd`

Der vorhandene GitHub-Actions-Workflow `Godot Headless Tests` läuft bei Pushes auf `main` und enthält unter anderem die vorhandenen Route-, Kampf-, Entwicklungs-, TM- und Datenbank-Regressionstests.

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

Etappen 1–5 bleiben als geschütztes Onboarding exakt erhalten:

- Etappe 1: 1 Gegner Lv.2
- Etappe 2: 1 Gegner Lv.3
- Etappe 3: 2 Gegner Lv.3
- Etappe 4: 2 Gegner Lv.4
- Etappe 5: 3 Gegner Lv.4

Ab Etappe 6 gilt:

`Referenzlevel = höchstes Level im eigenen Team`

Gegnerlevel nach Gruppengröße:

- 1 Gegner: Referenzlevel +5
- 2 Gegner: Referenzlevel +2
- 3 Gegner: Referenzlevel ±0
- 4 Gegner: Referenzlevel -2

Immer auf Level 1–100 begrenzen.

Die bisherigen festen Zehner-Levelplateaus entfallen vollständig.

Bei Etappe 6 erscheint einmal pro Run ein Hinweis, dass sich das Gegnerniveau ab jetzt nach dem höchstleveligen eigenen Pokémon richtet. Die bisherigen Hinweise bei Etappe 11/21/31/... entfallen.

## EP-Tempo

Level 100 bleibt die Obergrenze.

Die individuellen Pokémon-Wachstumskurven bleiben unverändert. Nur die normale Etappenkampf-EP-Menge wird zunächst als Balancing-Test auf 50 % des heutigen Werts gesetzt.

Bosskämpfe verwenden dieselbe normale Etappenkampf-EP wie normale Etappenkämpfe. Kein 2×-Boss-EP-Bonus mehr.

## Wegereignisse

Aktiver Pool nach dem Umbau:

1. Heilquelle
2. Fangwiese
3. Fundstelle
4. Trainingsplatz
5. Besondere Begegnung / Boss

`Direkter Pfad` und `Gefährlicher Pfad` werden entfernt.

Pro Etappe werden drei verschiedene Ereignisse vollständig zufällig aus diesen fünf gezogen. Keine feste Position mehr und keine Sonderregel, dass Slot 1 Heilquelle oder Fangwiese sein muss.

Bei gleichmäßiger Gewichtung ergibt das:

- 90 % Chance, dass mindestens Heilquelle oder Fangwiese in der Auswahl ist
- 30 % Chance, dass beide enthalten sind
- 10 % Chance, dass weder Heilquelle noch Fangwiese enthalten ist; dann besteht die Auswahl aus Fundstelle, Trainingsplatz und Boss

Die anfängliche Gewichtung aller fünf Ereignisse bleibt gleich. Erst Tests dürfen später eine Gewichtungsänderung begründen.

## Fangwiese

Basis-Fanglevel:

`höchstes eigenes Pokémon-Level - 3`, mindestens Lv.1.

Maximal drei Pokémon-Angebote pro Fangwiese:

- Suche 1: 100 % des Basis-Fanglevels
- Suche 2: 75 %, abgerundet
- Suche 3: 50 %, abgerundet

Minimum immer Lv.1. Nach Suche 3 keine weitere Suche.

Ein gefundenes Pokémon wird nicht mehr automatisch angenommen. Der Spieler darf es ansehen, aufnehmen bzw. bei vollem Team ersetzen oder weitersuchen. Nach der dritten Ablehnung endet die Fangwiese ohne Fang. Keine +25-%-EP-Trostbelohnung mehr.

## Begegnungshäufigkeit nach Speziesfamilie

Grundwert einer Familie:

`Familien-Fangrate = Durchschnitt der Fangraten aller Mitglieder der Entwicklungsfamilie`

Dieser vorberechnete Familienwert soll in der Pokémon-Datenbasis gespeichert werden; die originale Fangrate jeder einzelnen Spezies bleibt unverändert bestehen.

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

Sie bietet sechs Alternativen; genau eine darf gewählt werden:

- Slots 1–3: drei zufällige, für das aktuelle Team tatsächlich nutzbare TMs
- Slot 4: ein zum Routenfortschritt passendes Heilitem, sofort einsetzbar, nicht einlagerbar
- Slots 5–6: zwei verschiedene zufällige Vitamine

Vitamine:

- Protein → Angriff
- Eisen → Verteidigung
- Kalzium → Status
- Carbon → Initiative
- Zink → KP

Erster sicherer Balancingwert für Vitamine: **+1 permanenter Endwertpunkt** im jeweiligen Attribut pro Anwendung. Um unendliches Stapeln über 90 Etappen zu verhindern, gilt zunächst ein Cap von **+10 Vitaminpunkten pro Attribut und individuellem Pokémon**. Der Bonus wird individuell am Pokémon gespeichert und darf bei Level-Up oder Entwicklung nicht verloren gehen. Dieser Wert ist ausdrücklich ein Testwert und darf nur auf Basis von Balancingtests angepasst werden.

Die bisherige Alternative `keine TM → +25 % EP` entfällt.

## Boss / Besondere Begegnung

- Bosslevel = höchstes eigenes Pokémon-Level +5, maximal Lv.100
- echter doppelter KP-Pool bleibt
- normale Etappenkampf-EP, kein Bonusmultiplikator
- nach vollständiger Abwicklung von EP, Level-Ups und Entwicklungen folgt eine vollständige Fundstelle als Zusatzbelohnung
- nach der Boss-Fundstelle ist die Etappe beendet; es darf kein zweiter Etappenkampf starten

Die bestehende gute Sequenzlogik des bisherigen Gefährlichen Pfads – erst Kampf, dann EP/Level-Up/Entwicklung, danach Belohnung – soll für den Boss wiederverwendet werden, bevor der Gefährliche Pfad endgültig entfernt wird.

## Geplante Umsetzungsphasen

A. Sicherheitsbaseline und Regression-Sperrliste
B. Datenbasis für Speziesfamilie und Familien-Fangrate
C. Dynamisches Gegnerscaling und neuer Etappe-6-Hinweis
D. EP-Tempo und zentrale Etappen-EP-Quelle
E. Fangwiese mit drei Suchen und Seltenheitsgewichtung
F. Fundstelle mit TM, Heilitem und Vitaminen
G. Spezialereignisse: Direkter/Gefährlicher Pfad entfernen, Boss umbauen
H. Verwaiste Altlogik kontrolliert aufräumen
I. Gesamttests und visuelle Godot-Prüfung

Nach jeder Phase muss der Stand wieder funktionsfähig sein. Wenn eine Regression außerhalb des gerade geänderten Systems auftaucht, wird sie zuerst behoben, bevor die nächste Phase beginnt.
