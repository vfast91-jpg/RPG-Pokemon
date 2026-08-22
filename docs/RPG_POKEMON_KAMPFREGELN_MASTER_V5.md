# RPG Pokémon – Zentrale Kampfregeln V5
## Kanonische Master-Designquelle

**Stand:** 2026-08-23  
**Status:** Verbindliche aktuelle Masterregel  
**Ersetzt:** `RPG_POKEMON_KAMPFREGELN_MASTER_V4.md`

Dieses Dokument hat bei Widersprüchen Vorrang vor älteren Guides, Demo-Dateien oder historischen Notizen.

---

# 1. Kampfstruktur

RPG-Pokémon verwendet ein aktives Wait-ATB-Kampfsystem.

Ein Team besitzt **maximal vier Pokémon insgesamt**.

- maximal 4 Pokémon pro Seite
- alle Teammitglieder sind Kampfteilnehmer
- **keine Reserve**
- keine Reserveplätze
- keine Kampfwechsel-Mechanik

Ein Kampf ist verloren, wenn alle vier Pokémon eines Teams kampfunfähig sind.

Historische Regeln mit sechs Teamplätzen, vier aktiven Plätzen und zwei Reserven sind überholt.

---

# 2. Zentrale Kampfwerte

Jedes Pokémon besitzt:

- KP
- Angriff
- Verteidigung
- **Statuswert**
- Geschwindigkeit

Technisch kann das Feld `special` weiterhin verwendet werden; im Design und Spielertext heißt es **Statuswert**.

## Angriff

Ein einziger zentraler Schadens-Angriffswert. Original physisch/speziell bleibt nur Attackenmetadatum.

## Verteidigung

Ein einziger zentraler Verteidigungswert.

## Statuswert

Der **Statuswert** ist der zentrale Wirkungswert für **quantitativ skalierbare taktische Effekte jenseits des direkten Attackenschadens**.

Verbindliche Grundregel:

> **Direkter KP-Schaden einer Attacke skaliert mit Angriff. Quantitativ skalierbare nicht-schädigende Wirkungskomponenten skalieren grundsätzlich mit dem Statuswert, sofern keine ausdrücklich definierte zentrale Sonderregel etwas anderes festlegt.**

Eine Attacke wird dafür **komponentenweise** betrachtet. Eine Schadensattacke kann also gleichzeitig einen Angriff-basierten Schadensanteil und einen Statuswert-basierten Zusatz-/Supportanteil besitzen. Die Kategorie „Statusattacke“ entscheidet nicht allein darüber, ob Statuswert verwendet wird.

Typische Statuswert-Komponenten sind:

- Buffs
- Debuffs
- skalierbare Kontrolle
- Heilung
- Schutz / Barrieren
- Genauigkeitsmanipulation
- ATB-Manipulation
- andere ausdrücklich quantitativ skalierbare Supportwirkungen

### Hybridattacken

Hybridattacken verwenden für jede Wirkung die passende Quelle.

Beispiel Drain-Attacke wie Absorber/Gigasauger:

- verursachter KP-Schaden → **Angriff**
- daraus entstehende skalierbare Rückheilung → **Statuswert**

Die konkrete Drain-Heilungsformel wird **zentral** festgelegt und darf nicht pro Attacke hartkodiert werden. Bis diese gemeinsame Formel kalibriert ist, gilt die Zuständigkeit bereits verbindlich, die numerische Migration der Drain-Attacken aber noch nicht als abgeschlossen.

### Was nicht automatisch mit Statuswert skaliert

Statuswert wird nicht künstlich in binäre oder fest definierte Regelmechaniken hineingedrückt. Ohne ausdrückliche Sonderregel skalieren daher insbesondere **nicht automatisch**:

- das bloße Anwenden eines standardisierten Hauptstatuszustands wie Paralyse, Schlaf, Gift oder Verbrennung
- feste Regelzustände wie Verhöhner, Zugabe oder Aussetzer
- Schutzschild als binärer Block der nächsten passenden Attacke
- Feldgefahren und andere feste Kampffeldregeln
- der standardisierte periodische Schaden eines bereits bestehenden Hauptstatuszustands
- Zurückschrecken, sofern die zentrale Zurückschrecken-Regel eine feste Wirkung definiert
- Wetteraktivierung; Wetterstärke und Wetterdauer gehören zum zentralen Wettersystem und skalieren nicht automatisch mit Statuswert

Eine ausdrücklich definierte zentrale Sonderregel hat immer Vorrang vor dem allgemeinen Statuswert-Standard.

## Geschwindigkeit

Bestimmt die ATB-Füllgeschwindigkeit.


## Verbindliches Spieler-Wording für Attributänderungen

Interne Kampfberechnungen dürfen weiterhin mit technischen Effekt-IDs und Multiplikatoren arbeiten. Diese Rohwerte sind **keine Spielertexte**.

Wenn eine Mechanik semantisch eines der zentralen Attribute verändert, muss die sichtbare Darstellung immer das tatsächlich veränderte Attribut nennen:

- `outgoing_damage` / verursachter-Schaden-Multiplikator → **Angriff**
- `incoming_damage` / eingehender-Schaden-Multiplikator → **Verteidigung**
- Genauigkeitsmultiplikator → **Genauigkeit**
- ATB-Zyklus-Multiplikator → **Geschwindigkeit**

Spielertexte verwenden Prozentwerte statt Roh-Multiplikatoren.

Verbindliche Umrechnung für einen internen Multiplikator `m`:

- Angriff: `(m − 1) × 100 %`
- Verteidigung bei internem eingehendem-Schaden-Multiplikator: `(1/m − 1) × 100 %`
- Genauigkeit: `(m − 1) × 100 %`
- Geschwindigkeit bei internem ATB-Zyklus-Multiplikator: `(1/m − 1) × 100 %`

Beispiele:

- intern `eingehender Schaden ×1,25` → Spielertext **Verteidigung −20 %**
- intern `verursachter Schaden ×1,25` → Spielertext **Angriff +25 %**
- intern `Genauigkeit ×0,80` → Spielertext **Genauigkeit −20 %**
- intern `ATB-Zyklus ×0,80` → Spielertext **Geschwindigkeit +25 %**

Verboten in Beschreibungen, Tooltips, Kampflog und anderen sichtbaren Spielertexten sind insbesondere:

- rohe Formulierungen wie `eingehender Schaden ×...`
- rohe Formulierungen wie `verursachter Schaden ×...`
- `ATB-Zyklus ×...`
- technische Effekt-IDs wie `incoming_damage_mod`, `outgoing_damage_mod` oder `atb_cycle_mod`
- englische interne Typ-IDs, wenn ein deutscher Anzeigename vorgesehen ist
- ungenaue Ersatzwörter wie „Defensive“, „Tempo“ oder „verwundbarer“, wenn tatsächlich **Verteidigung** bzw. **Geschwindigkeit** verändert wird

Wenn die konkrete Prozentstärke erst zur Laufzeit aus dem Statuswert des Anwenders entsteht, darf die dauerhafte Attackenbeschreibung qualitativ bleiben, zum Beispiel „senkt die Verteidigung“. Der Tooltip berechnet und zeigt den für den aktuellen Anwender tatsächlich geltenden Prozentwert.

Diese Regel gilt nur für echte Attributänderungen. Eigenständige Mechaniken wie Wetter, Schutzschild, Lichtschild, Rückstoß oder direkter prozentualer Schaden dürfen weiterhin ihre eigene Wirkung benennen, sofern sie **nicht** bloß eine versteckte Änderung von Angriff, Verteidigung, Genauigkeit oder Geschwindigkeit sind.

---

# 3. Level-Skalierung

## KP

`floor((2 * base_hp * level) / 100) + level + 10`

## Angriff / Verteidigung / Geschwindigkeit

`floor((2 * base_stat * level) / 100) + 5`

## Statuswert

`raw = floor((2 * base_special * level) / 100) + 5`

Wenn `raw <= 25`: `status = raw`

Sonst:

`x = raw - 25`

`status = floor(25 + (20 * x) / (x + 40))`

---

# 4. Temporäre taktische Effekte

Die alte Defaultregel „nur nächste Aktion / nächster Treffer / nächste Accuracy-Prüfung“ ist überholt.

Aktueller Standard:

> Ein normaler temporärer Buff, Debuff, Genauigkeits-, Schutz- oder Kontrolleffekt gilt für die **nächsten 3 eigenen Aktionen des betroffenen Pokémon**.

Jedes betroffene Pokémon führt seinen eigenen Zähler.

Der Zähler sinkt nach jeder eigenen vollständig abgewickelten Aktion um 1.

Erneute Anwendung setzt die Dauer in der Regel wieder auf 3, sofern die Attacke nicht ausdrücklich anders definiert ist.

## Ausnahme Schutzschild

Schutzschild blockiert nur die **nächste passende feindliche Attacke**, die den Anwender treffen würde, und wird danach verbraucht.

Flächenattacke: nur das geschützte Pokémon ignoriert die Attacke; andere Ziele werden normal aufgelöst.

Mehrfachtreffer: die gesamte Attacke gegen das geschützte Pokémon wird blockiert.

Bereits aktive periodische Effekte, eigener Rückstoß oder Verwirrungs-Selbsttreffer werden nicht durch Schutzschild verhindert.

Bei unmittelbarer Wiederholung gilt aktuell:

- erste Anwendung nach anderer Aktion: 100 %
- direkte Wiederholung: 33 %
- nächste direkte Wiederholung: 11 %
- weitere Wiederholungen jeweils erneut × 1/3
- jede andere Aktion setzt die Kette zurück

---

# 5. RPG-AP und ATB

RPG-AP werden nicht verbraucht. Sie bestimmen die Länge des nächsten ATB-Zyklus.

| Original-PP | RPG-AP |
|---:|---:|
| 40 | 1 |
| 35 | 2 |
| 30 | 3 |
| 25 | 4 |
| 20 | 5 |
| 15 | 6 |
| 10 | 7 |
| 5 | 8 |

Die sichtbaren RPG-AP 1–8 sind festgelegt.

Die konkrete numerische AP→ATB-Multiplikatorkurve bleibt zentral balancierbar.

---

# 6. Eröffnungsphase / Runde 0

Bestimmte Prioritätsattacken können vor dem normalen ATB-Kampf in einer Eröffnungsphase verwendet werden.

- Nutzung ist freiwillig
- Verfügbarkeit ist datengetrieben
- mehrere Eröffnungsattacken werden nach Geschwindigkeit aufgelöst
- danach starten die normalen ATB-Leisten

**Verbindliche Timeflow-Bedeutung von Priorität:**

- Die klassische Pokémon-Prioritätsreihenfolge gilt **nicht** während des normalen ATB-Kampfes.
- `priority_reference` darf als Original-/Quelldatum erhalten bleiben.
- Ob eine Attacke in Runde 0 verfügbar ist, wird ausdrücklich über die zentrale Eröffnungsphasen-Regel bzw. ein Feld wie `opening_phase` festgelegt.
- Außerhalb der Eröffnungsphase entsteht aus einem positiven Original-Prioritätswert **kein automatisches Vorziehen** vor andere reguläre Aktionen.
- Benötigt eine Attacke zusätzlich besondere ATB-Eigenschaften, müssen diese separat und ausdrücklich designt werden.

Priorität bedeutet außerdem nicht automatisch extrem niedrige RPG-AP.

---

# 7. Zielregeln und Aggro

Normale offensive Einzelzielattacken müssen den Gegner mit der **höchsten Aggro** wählen.

Bei Gleichstand entscheidet Teamposition:

> 1 > 2 > 3 > 4

Keine freie Einzelzielwahl und kein Zufall bei Gleichstand.

Flächenattacken dürfen die Einzelziel-Aggroregel umgehen.

Mögliche zentrale Zielarten:

- Gegner mit höchster Aggro
- Anwender selbst
- alle Gegner
- alle vier Verbündeten
- alle anderen aktiven Pokémon
- gesamtes Kampffeld

Es gibt keine Reserve-Zielart.

## Aggro-Halbierung nach erfolgreicher gegnerischer Einzelzielattacke

Wird ein Pokémon von einer **gegnerischen Einzelzielattacke erfolgreich getroffen**, wird seine aktuelle Aggro **nach vollständiger Auflösung der gesamten Attacke genau einmal halbiert**:

`Aggro_neu = Aggro_alt × 0.5`

Diese Regel ist unabhängig von der Attackenkategorie und von der Art der Wirkung. Sie gilt insbesondere für:

- physische Einzelzielattacken
- spezielle Einzelzielattacken
- reine Statusattacken
- Debuffs und Kontrolleffekte
- Einzelzielattacken mit Schaden und Zusatzeffekt

Maßgeblich ist, dass die **Attacke selbst als gegnerische Einzelzielattacke** ausgeführt und das Ziel erfolgreich getroffen wurde. Die Halbierung darf deshalb **nicht daran gekoppelt werden, ob KP-Schaden verursacht wurde**.

Zusätzliche verbindliche Regeln:

- Mehrfachtreffer gegen dasselbe Einzelziel halbieren die Aggro **nur einmal nach der vollständigen Attacke**, nicht pro Treffer.
- Flächen- und Mehrzielattacken lösen **keine Aggro-Halbierung** aus – weder bei Schaden noch bei Status-/Kontrollwirkungen.
- Eine Flächen- oder Mehrzielattacke bleibt für diese Regel eine Flächen-/Mehrzielattacke, auch wenn beim Ausführen zufällig nur noch ein gültiges Ziel vorhanden ist.
- Verfehlt die Attacke oder wird sie vollständig abgewehrt bzw. trifft aufgrund einer Immunität nicht erfolgreich, erfolgt **keine Aggro-Halbierung**.
- Diese Halbierung ist eine zentrale Kampfregel und darf nicht pro Attacke als Sondermechanik hartkodiert werden.

---

# 8. Aggro-Erzeugung

Aggro entsteht aus **tatsächlicher Wirkung**.

## Schaden

Mehr tatsächlich verursachter Schaden erzeugt mehr Aggro.

## Heilung

Nur tatsächlich wiederhergestellte KP erzeugen Heilungs-Aggro.

## Taktische Effekte

Status-, Support- und Kontrolleffekte erzeugen Aggro nach tatsächlich angewendeter Wirkung.

## Feste Status-Aggro

Aktuelle Referenzen:

- Vergiftung: 20 Aggro bei erfolgreicher Anwendung
- Schlaf: 40 Aggro bei erfolgreicher Anwendung

Keine Status-Aggro bei Miss oder Immunität.

---

# 9. Genauigkeit und Verfehlen

Trefferprüfung erfolgt zentral.

Bei Verfehlen:

- kein Schaden
- keine Treffer-Zusatzwirkung
- keine wirkungsabhängige Aggro

Mehrzielattacken würfeln Genauigkeit pro Ziel, sofern nicht ausdrücklich anders designt.

Genauigkeitsmanipulation erfolgt multiplikativ; klassische Accuracy/Evasion-Stat-Stufen werden nicht verwendet.

Temporäre Genauigkeitseffekte folgen grundsätzlich der Drei-eigene-Aktionen-Regel.

---

# 10. Warten

Jedes Pokémon besitzt die Aktion `Warten`.

Warten:

- führt keine Attacke aus
- reduziert eigene Aggro deutlich
- verkürzt die nächste ATB-Phase

Die konkreten Werte bleiben zentral konfigurierbar.

---

# 11. Schaden und Volltreffer

Schadensberechnung erfolgt zentral und typabhängig.

Original physisch/speziell verwendet denselben zentralen Angriffswert und dieselbe zentrale Verteidigung.

Volltrefferstandard:

- 5 % Chance
- ×1,5 Schaden

High-Crit-Attacken verwenden eine zentrale erhöhte Volltrefferchance; aktuell 12,5 % als Designreferenz.

Bei Mehrziel-/Mehrfachtreffern wird pro relevantem Treffer/Ziel separat gewürfelt.

---

# 12. Standardisierte Statuszustände

## Hauptstatus

- Paralyse
- Verbrennung
- Vergiftung
- schwere Vergiftung
- Schlaf
- Gefroren

Maximal **ein Hauptstatus gleichzeitig**.

## Flüchtiger Status

Beispiel: Verwirrung.

Statusdefinitionen sind zentral. Attacken verweisen nur auf Status-IDs.

---

# 13. Schlaf

Schlaf dauert zufällig **1–3 eigene Aktionsmöglichkeiten**.

Bei jeder vollen ATB während Schlaf wird eine Schlaf-Aktionsmöglichkeit verbraucht und das Pokémon führt keine normale Aktion aus.

Sind alle Schlaf-Aktionsmöglichkeiten verbraucht, handelt das Pokémon bei seiner nächsten eigenen Gelegenheit wieder normal.

---

# 14. Immunitäten

Statusimmunitäten werden zentral geprüft.

Beispiele:

- Gift-/Stahl-Typen gegen Vergiftung gemäß zentraler Typregel
- Pflanzen-Pokémon gegen Puderattacken

Eine Attacke definiert keine lokale Kopie derselben Immunität.

---

# 15. Attacken – datengetriebener Grundsatz

Jede Attacke besitzt genau eine zentrale Definition.

Pflichtfelder umfassen mindestens:

- ID
- Name
- **Emoji**
- Typ
- Kategorie
- Stärke
- Genauigkeit
- Original-PP
- RPG-AP
- Zielart
- Kontakt
- Flächenwirkung
- Effekte
- Statuswert-Skalierung
- Aggroverhalten
- Sonderregeln

Pokémon-Spezies referenzieren nur Attacken-IDs.

Das Emoji ist Pflicht und wird sowohl in der UI als auch für einfache Attackenanimationen verwendet.

## 15.1 Gemeinsame zentrale Zustände und Attacken-Wechselwirkungen

Wenn mehrere Attacken auf denselben Kampfzustand reagieren, muss dieser Zustand **zentral** modelliert werden.

Verboten sind voneinander unabhängige, attackenspezifische Sonderflags, die dieselbe Lage mehrfach nachbauen.

Ein gemeinsamer Zustand soll mindestens eindeutig festlegen können:

- zentrale Zustands-ID
- betroffenes Pokémon bzw. Kampffeld
- Quelle/Anwender, falls relevant
- Dauer bzw. Verbrauchsregel
- welche Attacken oder zentralen Systeme darauf reagieren
- was bei Ende, Verbrauch, Kampfunfähigkeit oder anderen Konflikten passiert

Referenzprinzip:

> `Schaufler` kann später den zentralen Zustand „unter der Erde“ setzen; `Erdbeben` reagiert auf genau diesen Zustand. Beide Attacken dürfen dafür nicht zwei unabhängige Sonderlösungen besitzen.

Solche Wechselwirkungen müssen durch echte Verhaltenstests abgesichert werden.

---

# 16. Mehrziel- und Flächenattacken

Bei Mehrzielattacken müssen Ziele unabhängig aufgelöst werden, wenn die Mechanik dies verlangt:

- Genauigkeit pro Ziel
- Volltreffer pro Ziel
- Statuschance pro Ziel
- Schaden und Immunitäten pro Ziel

Flächenattacken können alle Gegner oder andere ausdrücklich definierte Zielgruppen treffen.

---

# 17. Zurückschrecken, ATB-Knockback und ATB-Pause

## Zurückschrecken

Zurückschrecken wird über eine zentrale **ATB-Knockback-Mechanik** abgebildet.

Referenz: Biss.

Feuerzahn und Luftschnitt verwenden dieselbe Mechanik mit ihren jeweiligen Chancen.

Das ist **kein Rückstoß**.

## Rückstoß

Rückstoß bedeutet Eigenschaden des Anwenders aufgrund des tatsächlich verursachten Schadens.

Beispiele: Bodycheck, Flammenblitz, Wellentackle.

## ATB-Pause

Originale Zwangswechselattacken wie Wirbelwind und Brüller können mangels Reserve nicht wechseln.

RPG-Übersetzung:

> Ziel-ATB wird vollständig pausiert; Pausendauer skaliert mit dem Statuswert des Anwenders.

Nach Ende der Pause läuft die Leiste vom vorherigen Stand weiter.

Die konkrete Statuswert→Zeit-Formel ist eine zentrale Kalibrierung und darf nicht pro Attacke unterschiedlich erfunden werden.

---

# 18. Heilung

Skalierbare Heilung verwendet grundsätzlich den **Statuswert** des Anwenders, sofern eine Attacke nicht ausdrücklich eine feste, binäre oder andere zentrale Sondermechanik besitzt.

Die zentrale Status-Kurve lautet:

`R = Status / (75 + Status)`

Natürlich auf 100 % begrenzte Heilwirkungen verwenden als Referenz:

> Heilungsanteil = `100 × R` Prozent der passenden Heilungsbasis.

Bei reinen Selbstheilungen kann die Heilungsbasis die eigenen maximalen KP sein. Move-spezifische Gewichtungen dürfen zentral auf diese Kurve aufsetzen, dürfen aber keine eigene konkurrierende Statusformel erfinden.

**Synthese** ist die Referenz für eine reine statuswertbasierte Selbstheilung. Wetterabhängige Änderungen an Synthese werden ausschließlich über das zentrale Wettersystem ergänzt.

**Drain-Attacken** sind Hybridattacken: Der Schaden wird über Angriff berechnet; die Rückheilung ist eine eigene Statuswert-Komponente. Die genaue gemeinsame Drain-Kalibrierung wird zentral festgelegt, bevor die Bestandsattacken numerisch migriert werden.

Aggro entsteht nur aus tatsächlich wiederhergestellten KP.

---

# 19. Teamweite Effekte

„Alle Verbündeten“ bedeutet immer **alle vier Pokémon des eigenen Teams**.

Es gibt keine Reserve.

Referenzen:

- Bodyguard: Schutz vor neuen Hauptstatuszuständen für nächste 3 eigene Aktionen jedes Teammitglieds
- Sorgensamen: Schlaf heilen + Schlafimmunität für nächste 3 eigene Aktionen jedes Teammitglieds
- Rückenwind: ATB-Beschleunigung für nächste 3 eigene Aktionen jedes Teammitglieds

Jeder Zähler läuft separat.

---

# 20. Wetter

Wetter ist ein **globaler Kampfzustand** und keine Statuswert-Skalierung einer einzelnen Attacke.

Es kann immer nur ein Wetter gleichzeitig aktiv sein. Neues anderes Wetter ersetzt vorhandenes Wetter.

Verbindliches Architekturprinzip:

> **Quelle aktiviert Wetter-ID → zentrales Wettersystem übernimmt Stärke, Wirkung und Dauer.**

Regentanz, Sonnentag und spätere Wetterquellen skalieren daher **nicht** mit Statuswert. Die auslösende Attacke bestimmt nur die Wetter-ID.

Für normales Timeflow-Wetter gilt aktuell:

- ein einziger kontinuierlicher Zeitbalken
- Standarddauer 50 Sekunden aktive Kampfzeit
- bei pausierter Spielerentscheidung pausiert auch die Wetterzeit
- Wetterdauer ist unabhängig von Geschwindigkeit, RPG-AP, ATB und Aktionen des Auslösers
- anderes Wetter ersetzt das aktive Wetter und startet mit voller eigener Dauer
- dasselbe aktive Wetter kann nicht erneut ausgelöst oder erneuert werden

Wetterwirkung und -dauer werden zentral definiert und nicht in einzelne Attacken dupliziert.

---

# 21. Aufladen, Nachladen, Bindung und erzwungene Sequenzen

Das System muss zentrale Mechaniktypen unterstützen für:

- Aufladeattacken
- Nachladeattacken
- Mehrfachtreffer
- Bindung/periodische Effekte
- erzwungene Aktionssequenzen
- Guard
- Recoil
- Wetter
- ATB-Knockback
- ATB-Pause

Beispiele:

- Solarstrahl: Aufladen, danach automatischer Abschuss
- Hyperstrahl/Gigastoß: nach erfolgreichem Treffer nächste eigene Aktionsmöglichkeit als Nachladen
- Feuerwirbel/Wickel: Bindung 4–5 Aktionen
- Blättertanz: 2–3 erzwungene Aktionen, danach Verwirrung

---

# 22. Schutzschild

Schutzschild:

- Selbstziel
- blockiert nächste feindliche Attacke gegen den Anwender vollständig
- bei AoE nur Anwender geschützt
- bei Multi-Hit gesamte Attacke gegen Anwender blockiert
- blockiert keine bereits laufenden periodischen Schäden
- blockiert keinen eigenen Rückstoß
- blockiert keinen Verwirrungs-Selbsttreffer
- direkte Wiederholungen werden zunehmend unwahrscheinlich (100 %, 33 %, 11 %, ...)
- andere Aktion setzt Wiederholungskette zurück

---

# 23. Entwicklung und Attackenfreischaltung

Entwicklungen sind automatisch und nicht verhinderbar.

Pokémon behalten alle bekannten Attacken.

Beim Entwickeln werden automatisch freigeschaltet:

- echte Entwicklungsattacken
- Level-1-/Wiedererlern-Attacken der neuen Spezies
- bereits „übersprungene“ Levelattacken der neuen Spezies, deren Lernlevel ≤ aktuellem Level ist

Dadurch ist kein Attacken-Erinnerer notwendig.

---

# 24. TM-Kompatibilität

Jede Entwicklungsstufe besitzt eine **eigene vollständige TM-Kompatibilitätsliste**.

Keine automatische Vererbung der TM-Liste von Vorstufen.

Für den frühen Rollout werden zunächst drei TMs pro Spezies/Linie praktisch verwendet; die Datenhaltung soll trotzdem vollständige Kompatibilität pro Entwicklungsstufe erlauben.

---

# 25. Traineraktionen

Trainer kann eine eigene ATB für ausdrücklich definierte Traineraktionen wie Fangversuche besitzen, soweit der jeweilige Modus dies vorsieht.

## Kein Item-System

Pokémon Timeflow besitzt aktuell **kein Item-System**.

Daher gilt verbindlich:

- keine getragenen Items
- keine Beeren
- keine Kampfitems
- keine neuen Attacken- oder Speziesmechaniken, die ein Item-System voraussetzen

Originalmechaniken, die zwingend von Items abhängen, müssen entweder sinnvoll in eine bestehende Timeflow-Mechanik übersetzt oder bewusst nicht übernommen werden. Ein Item-System darf nicht nebenbei für eine einzelne Attacke eingeführt werden.

## Kein Wechseln

Eine Traineraktion „Wechseln“ existiert im aktuellen Regelstand **nicht**, weil es keine Reserve gibt.

Historische Wechsel-/Reserve-Regeln sind überholt.

---

# 26. Kampfunfähigkeit

Wird ein Pokémon kampfunfähig, bleibt sein Platz ohne Nachrücken aus einer Reserve.

Es gibt kein Ersatz-Pokémon aus einem fünften/sechsten Slot.

Sind alle vier Pokémon einer Seite kampfunfähig, ist der Kampf beendet.

---

# 27. Tests – verbindlicher Standard

Für Sondermechaniken sind echte automatische Verhaltens-/Headless-Tests erforderlich.

Ein reines Datenschema-/ID-Audit ist nicht ausreichend.

Je nach Mechanik prüfen:

- Trigger
- Zielauflösung
- Dauer
- Herunterzählen
- Verbrauch
- Immunitäten
- Miss
- Schaden
- Heilung
- Aggro
- Mehrzielverhalten
- Statuskonflikte
- ATB-Interaktion
- Wetterinteraktion

Unbekannte Mechanik-IDs oder nicht unterstützte Status-/Wettertypen sollen in Entwicklung/Tests deutlich fehlschlagen und niemals still ignoriert werden.

---

# 28. Überholte Regeln – ausdrücklich nicht mehr verwenden

Folgendes ist nicht mehr gültig:

- ein allgemeines Item-/Beeren-/Held-Item-System
- klassische Prioritätsreihenfolge während des normalen ATB-Kampfes
- Terakristallisierung als aktuelles Kampfsystem; insbesondere `Tera Blast / Tera-Ausbruch` wird nicht in den Timeflow-Attackenpool aufgenommen

- sechs Pokémon pro Team
- zwei Reserveplätze
- Nachrücken aus Reserve
- Kampfwechsel zwischen aktiv und Reserve
- erzwungene Wechsel durch Wirbelwind/Brüller
- optionale/verhinderbare Entwicklungen
- Vier-Attacken-Limit
- Attacken-Erinnerer als notwendiges Kernsystem
- klassische permanente Stat-Stufen für normale Buffs/Debuffs
- „nur nächste Aktion“ als allgemeine Dauer temporärer Effekte
- separate Accuracy/Evasion-Stat-Stufentabelle
- Attackenmechanik pro Pokémon duplizieren

---

# 29. Kurzreferenz

**Team:** 4 Pokémon insgesamt, keine Reserve.  
**Entwicklung:** automatisch und verpflichtend.  
**Attackenwissen:** unbegrenzt, nichts wird automatisch vergessen.  
**TM:** vollständige Liste pro Entwicklungsstufe separat.  
**Statuswert:** technisches Feld `special`; direkter Attackenschaden → Angriff, quantitativ skalierbare nicht-schädigende Wirkung → grundsätzlich Statuswert.  
**Temporäre Effekte:** standardmäßig nächste 3 eigene Aktionen des Betroffenen.  
**Schutzschild:** nur nächste passende feindliche Attacke.  
**Aggro:** Einzelziel greift höchste Aggro an; Gleichstand Position 1>2>3>4.  
**RPG-AP:** keine Ressource, sondern Zeitkosten 1–8.  
**Emoji:** Pflichtfeld jeder Attacke.  
**Wetter:** globaler zentraler Zustand; Aktivierung skaliert nicht mit Statuswert.  
**Wirbelwind/Brüller:** Statuswert-basierte ATB-Pause statt Wechsel.  
**Tests:** Sondermechaniken brauchen echte Verhaltenstests.

---

# 30. Quellenpriorität für neue Chats

Für weitere Pokémon- und Attackendesigns sollen neue Chats diese Dateien als Basis verwenden:

1. `RPG_POKEMON_KAMPFREGELN_MASTER_V5.md`
2. `POKEMON_SPECIES_DESIGN_GUIDE_V5.md`
3. `RPG_POKEMON_ATTACKEN_DESIGN_GUIDE_V5.md`
4. die jeweils aktuellsten Pokémon- und Attacken-Datenbanken

Ältere V1/V2/V3/V4-Dateien sind historische Quellen und dürfen bei Widerspruch nicht verwendet werden.
