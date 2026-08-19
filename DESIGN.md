# DESIGN.md

## Zielbild

Kleines Godot-4-RPG mit taktischem Wait-ATB-Kampfsystem. Teams besitzen maximal 6 Monster, davon kämpfen bis zu 4 gleichzeitig. Rollen entstehen aus Werten und Fähigkeiten, nicht aus festen Klassen.

## Kampfwerte

Jedes Monster besitzt KP, Angriff, Verteidigung, Spezial und Geschwindigkeit.

- Angriff skaliert Schaden.
- Verteidigung reduziert Schaden.
- Spezial skaliert Status-, Buff-, Debuff-, Kontroll- und Supportwirkungen; Spezial ist kein zweiter Schadenswert.
- Geschwindigkeit bestimmt die ATB-Füllrate.

## Wait-ATB

Jedes aktive Monster hat eine eigene ATB-Leiste. Zusätzlich besitzt jeder Trainer eine eigene Trainer-ATB. Wenn eine Spieleraktion ausgewählt werden muss, pausiert die Kampfzeit.

Monster dürfen Attacken benutzen oder Warten. Trainer dürfen Items benutzen, wechseln, wilde Monster fangen und später ggf. fliehen.

Attacken besitzen Zeitkosten bzw. Erholungsmodifikatoren. Mächtige Wirkungen können durch längere nächste ATB-Zyklen bezahlt werden. Verfehlen reduziert die folgende Erholung leicht.

## Eröffnungsphase / Runde 0

Vor dem normalen ATB dürfen geeignete Attacken freiwillig eingesetzt werden. Das Attackendatenfeld `usable_in_opening_phase` steuert dies. Entscheidungen werden gesammelt und bei mehreren Aktionen nach Geschwindigkeit aufgelöst. Danach starten die normalen ATB-Leisten.

## Aggro

Jedes aktive Monster besitzt sichtbare Aggro.

Normale offensive Einzelzielattacken müssen das gegnerische aktive Monster mit der höchsten Aggro treffen. Bei Gleichstand entscheidet Teamposition 1 vor 2 vor 3 vor 4. Diese Regel gilt symmetrisch für Spieler und KI.

Aggro entsteht aus tatsächlicher Wirkung plus optionalem Grundwert. Schaden, tatsächliche Heilung und Status-/Supportwirkung können eigene Skalierungen besitzen. Verfehlte Wirkungen erzeugen keine wirkungsabhängige Aggro.

Nach Auflösung einer gegnerischen offensiven Aktion gegen ein Monster wird dessen aktuelle Aggro standardmäßig mit `0.5` multipliziert.

Start-Aggro berücksichtigt Level und grundlegende Kampfstärke, bleibt aber bewusst moderat skaliert.

## Warten

Warten ist eine echte Monsteraktion. Es senkt die eigene Aggro deutlich und verkürzt die nächste ATB-Phase.

## Ziele

Das System unterstützt mindestens:

- höchsten Aggro-Gegner
- Anwender
- einzelnen Verbündeten
- alle Gegner
- alle Verbündeten
- gesamtes Kampffeld

Flächenattacken umgehen die Einzelziel-Aggroregel. Fangversuche sind Traineraktionen und dürfen ein wildes Ziel frei auswählen.

## Status und länger dauernde Effekte

Der Effektaufbau muss Angriff/Verteidigung/Geschwindigkeit verändern, Guard/Schutz erlauben und später Mehrfachtreffer, Aufladen, Kanalisierung und fortlaufende Effekte ermöglichen.

## Wechseln

Wechseln verbraucht Trainer-ATB. Einwechselnde Monster erhalten zentral konfigurierbare ATB- und Aggro-Startwerte. Wechseln darf Aggro nicht trivial auf null zurücksetzen.

## Fangen

Bei wilden Mehrfachkämpfen darf die Traineraktion Fangball genau ein beliebiges wildes Monster anvisieren. Fangchance hängt mindestens von verbleibenden KP, Spezies-Fangwert, Status und Ballstärke ab. Ein gefangenes Monster verlässt den Kampf sofort und wird nicht direkt eingewechselt.

## Aktueller Prototypumfang

Der erste technische Stand priorisiert:

1. Projektarchitektur
2. ATB
3. Aggro und Zielresolver
4. Attackendaten und einfache Effekte
5. 4-gegen-4-Sandbox
6. Trainer-ATB
7. Warten
8. Eröffnungsphase als Kernlogik
9. Testwelt

Interaktive Wechsel-/Fangdialoge, vollständige Status-UI, finale Balance, Typen, Story, Entwicklung und finale Assets folgen später.
