# RPG Pokémon – Attacken-Design-Guide V5
## Verbindliche Vorlage für neue Attacken

**Stand:** 2026-08-23  
**Status:** Kanonische aktuelle Attacken-Designvorlage  
**Ersetzt:** `RPG_POKEMON_ATTACKEN_DESIGN_GUIDE_V4.md`

---

# 0. Zweck und Priorität

Dieses Dokument beschreibt, wie neue Attacken recherchiert, in das RPG-ATB-System übersetzt und als zentrale Datendefinition vorbereitet werden.

Für allgemeine Kampfregeln gilt immer zuerst:

> `RPG_POKEMON_KAMPFREGELN_MASTER_V5.md`

Eine Attacke wird **genau einmal global** designt. Pokémon-Spezies referenzieren nur ihre Attacken-ID.

---

# 1. Ausgangspunkt

Standardreferenz ist Generation 9 / Karmesin & Purpur, sofern die Attacke bzw. Spezies dort verfügbar ist.

Möglichst direkt übernehmen:

- Name
- Typ
- Original-Kategorie als Referenz
- Original-Stärke
- Genauigkeit
- Original-AP/PP
- Priorität als Referenz
- Kontakt ja/nein
- Zielcharakter
- Zusatzeffekte und Chancen

Dann wird die Wirkung in die RPG-Systeme übersetzt.

Bevor eine Attacke neu entworfen wird, muss außerdem der **aktuelle Projektstand** geprüft werden:

- existiert bereits eine zentrale Attackendefinition?
- ist sie in der aktuellen Attacken-Datenbank vollständig?
- besitzt sie echtes Runtime-Verhalten oder nur Daten/Freitext?
- ist die Mechanik vollständig, teilweise oder gar nicht implementiert?
- existiert die benötigte zentrale Mechanik bereits unter einer anderen Attacke?

Vollständig vorhandene Attacken werden nur wiederverwendet und **nicht erneut designt**.

---

# 2. Zentrale Datenfelder

Eine fertige Attacke soll mindestens enthalten:

- `id`
- `name`
- **`description`** – Pflichtfeld; ausschließlich spielerlesbarer Text
- **`emoji`** – Pflichtfeld
- `type`
- `category`
- `power`
- `accuracy`
- `original_pp`
- `rpg_ap`
- `target`
- `area`
- `contact`
- `priority_reference`
- `opening_phase`
- `effects`
- `status_scaling`
- `aggro`
- `special_rules`
- benötigte Verhaltenstests bei Sondermechaniken

Das Emoji wird sowohl in der UI als auch für die einfache Attackenanimation verwendet.


## 2.1 Verbindliche Trennung: Spielertext vs. Technik

Eine Attackendefinition enthält sowohl **spielerlesbare Texte** als auch **interne Mechanikdaten**. Diese beiden Ebenen dürfen nicht vermischt werden.

### Spielertext

Direkt spielerlesbar sind insbesondere:

- `name`
- `description`
- daraus erzeugte Tooltips, Effektzusammenfassungen und Kampflog-Texte

Für Spielertexte gelten ausschließlich die kanonischen Begriffe:

- **Angriff**
- **Verteidigung**
- **Statuswert**
- **Geschwindigkeit**
- **Genauigkeit**
- **KP**
- **RPG-AP**

Wenn eine Attacke eines dieser Attribute verändert, muss genau dieses Attribut genannt werden.

Nicht verwenden:

- „eingehender Schaden ×1,25“
- „verursachter Schaden ×0,8“
- „ATB-Zyklus ×0,8“
- `incoming_damage_mod`
- `outgoing_damage_mod`
- `atb_cycle_mod`
- „Defensive“, wenn tatsächlich Verteidigung gemeint ist
- „Tempo“, wenn tatsächlich Geschwindigkeit gemeint ist
- „verwundbarer“, wenn technisch die Verteidigung sinkt

### Technische Daten

Interne Felder dürfen weiterhin Formeln, IDs und Multiplikatoren enthalten, wenn die Runtime sie benötigt. Dazu gehören insbesondere:

- `effects`
- `status_scaling`
- `special_rules`
- `required_behavior_tests`
- reine Design-/Implementierungsnotizen

Diese Felder werden **niemals ungefiltert als Spielertext ausgegeben**.

### Prozentdarstellung

Wenn intern ein Multiplikator `m` verwendet wird, gilt für die sichtbare Darstellung:

| Interne Bedeutung | Spieleranzeige |
|---|---|
| verursachter-Schaden-Multiplikator | Angriff: `(m−1) × 100 %` |
| eingehender-Schaden-Multiplikator | Verteidigung: `(1/m−1) × 100 %` |
| Genauigkeitsmultiplikator | Genauigkeit: `(m−1) × 100 %` |
| ATB-Zyklus-Multiplikator | Geschwindigkeit: `(1/m−1) × 100 %` |

Beispiele:

- intern `eingehender Schaden ×1,25` → **Verteidigung −20 %**
- intern `verursachter Schaden ×1,25` → **Angriff +25 %**
- intern `Genauigkeit ×0,80` → **Genauigkeit −20 %**
- intern `ATB-Zyklus ×0,80` → **Geschwindigkeit +25 %**

Bei Statuswert-Skalierung muss `description` **keinen erfundenen festen Prozentwert** enthalten. Beispiel:

> „Senkt die Verteidigung des Ziels für dessen nächste drei eigene Aktionen.“

Der konkrete Prozentwert wird erst mit den aktuellen Kampfwerten berechnet und im Laufzeit-Tooltip angezeigt.

### Ausnahme: echte eigenständige Mechanik

Nicht jeder Schadens- oder ATB-Effekt ist eine Attributänderung. Wetter, Schutzschild, Lichtschild, Rückstoß, feste prozentuale KP-Effekte oder echte ATB-Pausen dürfen ihre eigene Mechanik benennen. Entscheidend ist: Ein Spielertext darf eine interne Attributänderung nicht als indirekten Schadens- oder Zyklusmultiplikator verstecken.

### Excel-Datenbank

Für die zentrale Attacken-Excel gilt:

- **Beschreibung** ist Spielertext und muss diese Regel vollständig einhalten.
- **Statuswirkung** ist eine Designzusammenfassung mit kanonischen Attributnamen; sie darf nicht ungefiltert als Tooltip verwendet werden.
- **Effekte**, **Statuswert-Skalierung**, **Spezialregeln** und **Notizen** sind interne Felder.
- Roh-Multiplikatoren gehören nur in interne Felder.
- Eine spätere Export-/Import-Pipeline darf interne Felder nicht versehentlich als Spielerbeschreibung verwenden.

---

# 3. Schaden und Kategorien

RPG-Pokémon besitzt nur einen zentralen Schadens-Angriffswert.

Original „physisch“ und „speziell“ dürfen als Attackenmetadaten erhalten bleiben, bestimmen aber **nicht** zwei verschiedene Angriffsattribute.

Schadensattacken benutzen den zentralen Angriffswert und die zentrale Verteidigung des Ziels gemäß Masterregel.

---

# 4. RPG-AP

RPG-AP werden **nicht verbraucht**. Sie bestimmen die Länge des nächsten ATB-Zyklus.

Standardumrechnung:

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

Die sichtbaren Werte 1–8 sind fest. Die konkrete AP→ATB-Multiplikatorkurve darf zentral weiter balanciert werden.

Sonderattacken können begründet abweichen, aber nie stillschweigend.

Prioritätsattacken erhalten **nicht automatisch niedrige AP**. Ihre Priorität wird primär über die zentrale Eröffnungs-/Runde-0-Regel behandelt.

Verbindlich gilt: `priority_reference` ist nur Original-/Quelldatum. Die spielmechanische Timeflow-Bedeutung wird über `opening_phase` bzw. die zentrale Runde-0-Regel festgelegt. Außerhalb von Runde 0 existiert **keine klassische Pokémon-Prioritätsreihenfolge**.

---

# 5. Statuswert

Der frühere Designname „Spezial“ heißt spielerisch **Statuswert**. Das technische Feld darf aus Kompatibilitätsgründen `special` bleiben.

Verbindlicher Standard für jede Attacke:

> **Direkter KP-Schaden skaliert mit Angriff. Jede quantitativ skalierbare nicht-schädigende Wirkungskomponente skaliert grundsätzlich mit Statuswert, sofern keine zentrale Sonderregel ausdrücklich etwas anderes festlegt.**

Die Prüfung erfolgt **pro Wirkungskomponente**, nicht pro Attackenkategorie. Deshalb kann auch eine physische oder spezielle Schadensattacke zusätzlich Statuswert verwenden.

Typische Statuswert-Komponenten:

- Buffs
- Debuffs
- skalierbare Kontrolle
- Heilung
- Schutz / Barrieren
- ATB-Manipulation
- Genauigkeitsmanipulation
- andere quantitativ skalierbare Supportwirkungen

Eine Attacke kann 1×, 2× oder eine andere ausdrücklich definierte Status-Gewichtung verwenden. Die Gewichtung wird auf die zentrale Statuskurve angewendet und darf keine lokale Konkurrenzformel erfinden.

## Hybridattacken

Mehrteilige Attacken dürfen unterschiedliche Werte für unterschiedliche Komponenten verwenden.

Beispiel Drain-Attacke:

- Schaden → Angriff
- Rückheilung → Statuswert

`status_scaling = none` ist für eine skalierbare nicht-schädigende Komponente nur dann korrekt, wenn bewusst eine feste/binäre Mechanik oder eine andere zentrale Sonderregel verwendet wird.

## Keine automatische Status-Skalierung

Nicht automatisch Statuswert-basiert sind unter anderem:

- bloße Anwendung eines standardisierten Hauptstatuszustands
- feste Regelzustände wie Verhöhner, Zugabe oder Aussetzer
- Schutzschild als binärer Einmalblock
- Feldgefahren
- standardisierter periodischer Hauptstatus-Schaden
- feste zentrale Zurückschrecken-Wirkung
- Wetteraktivierung

Eine ausdrückliche zentrale Sonderregel hat Vorrang.

Die zentrale Statuskurve lautet:

`R = Status / (75 + Status)`

Move-Gewichtungen werden erst danach angewendet. Natürlich auf 100 % begrenzte Wirkungen verwenden als Referenz `100 × R` Prozent bzw. Prozentpunkte.

---

# 6. Verbindlicher Standard für temporäre Effekte

Die alte Regel „nur nächste Aktion / nächster Treffer / nächste Genauigkeitsprüfung“ ist **nicht mehr der Standard**.

Aktueller Standard:

> Temporäre Buffs, Debuffs, Genauigkeits-, Schutz- und Kontrollwirkungen gelten grundsätzlich für die **nächsten 3 eigenen Aktionen des jeweils betroffenen Pokémon**.

Der Zähler wird pro betroffenem Pokémon separat geführt.

Er sinkt nach jeder eigenen vollständig abgewickelten Aktion des betroffenen Pokémon.

Neu anwenden setzt die Dauer normalerweise wieder auf 3, statt unbegrenzt zu stapeln, sofern die Attacke nichts anderes definiert.

## Wichtige Ausnahme: Schutzschild

`Protect / Schutzschild` blockiert nur die **nächste passende feindliche Attacke**, die den Anwender betreffen würde, und wird danach verbraucht.

Es verwendet **nicht** die allgemeine Drei-Aktionen-Dauer.

Weitere Attacken dürfen abweichende Dauern besitzen, wenn dies explizit Teil ihres Designs ist, z. B. Bindung 4–5 Aktionen oder Auflade-/Nachladezustände.

---

# 7. Zielregeln

Unterstützte Zielarten müssen zentral und datengetrieben bleiben:

- Gegner mit höchster Aggro
- Anwender selbst
- alle Gegner
- alle vier Verbündeten / eigenes gesamtes Viererteam
- alle anderen aktiven Pokémon
- gesamtes Kampffeld

Es gibt **keine Reserve** und keine Reserveziele.

Normale offensive Einzelzielattacken wählen den Gegner mit der höchsten Aggro. Bei Gleichstand entscheidet Teamposition 1 > 2 > 3 > 4.

Flächenattacken dürfen diese Einzelzielregel umgehen.

## Globale Ziel-Aggro-Regel

Bei jeder **erfolgreich treffenden gegnerischen Einzelzielattacke** wird die aktuelle Aggro des getroffenen Pokémon **nach vollständiger Auflösung der gesamten Attacke genau einmal halbiert**:

`Aggro_neu = Aggro_alt × 0.5`

Diese Halbierung gehört zur zentralen Kampfauflösung und **nicht zum individuellen Attackendesign**. Eine Attacke darf dafür keinen eigenen Sonderfall benötigen.

Für das Attackendesign gilt deshalb verbindlich:

- Die Regel gilt unabhängig davon, ob die Attacke physisch, speziell oder eine Statusattacke ist.
- Sie gilt auch für reine Debuffs, Status- und Kontrolleffekte, solange die Attacke ein gegnerisches Einzelziel erfolgreich trifft.
- Sie darf nicht davon abhängig gemacht werden, ob die Attacke KP-Schaden verursacht.
- Mehrfachtreffer gegen dasselbe Einzelziel lösen die Halbierung nur **einmal nach der gesamten Attacke** aus.
- Flächen- und Mehrzielattacken lösen **keine** Ziel-Aggro-Halbierung aus, auch wenn aktuell nur ein gültiges Ziel vorhanden ist.
- Verfehlen, vollständige Abwehr oder eine Immunität ohne erfolgreichen Treffer lösen keine Halbierung aus.

---

# 8. Kein Wechsel-/Reserve-Design

Das Team besteht nur aus vier Pokémon. Es gibt keine Reserve und keine Kampfwechsel-Mechanik.

Originalattacken, deren Kernwirkung das Erzwingen eines Wechsels ist, müssen deshalb in eine passende ATB-Kontrollwirkung übersetzt werden.

## Referenz: Wirbelwind / Brüller

Wirbelwind und später Brüller verwenden dieselbe zentrale Mechanik:

> Die ATB-Leiste des gegnerischen Ziels wird vollständig pausiert.

Die Pausendauer hängt vom aktuellen Statuswert des Anwenders ab.

Die genaue zentrale Umrechnung Statuswert → reale Pausendauer wird im Kampfsystem kalibriert und **nicht pro Attacke erfunden**.

Nach Ende der Pause läuft die ATB-Leiste vom vorherigen Stand weiter.


## 8.1 Kein Item-System und keine Tera-Mechanik

Pokémon Timeflow besitzt aktuell **kein Item-System**.

Daher dürfen Attacken nicht stillschweigend voraussetzen:

- getragene Items
- Beeren
- Kampfitems
- Itemverbrauch oder Itemtausch

Originaleffekte, die zwingend an Items gebunden sind, müssen bewusst in eine vorhandene Timeflow-Mechanik übersetzt oder als nicht übertragbar markiert werden. Für eine einzelne Attacke darf kein Item-System neu erfunden werden.

`Tera Blast / Tera-Ausbruch` wird vollständig ignoriert und nicht als zu designende Attacke aufgenommen.

---

# 9. Statuszustände

Standardisierte Statuszustände werden zentral definiert und von Attacken nur referenziert.

Dazu gehören insbesondere:

- Paralyse
- Verbrennung
- Vergiftung
- schwere Vergiftung
- Schlaf
- Gefroren
- Verwirrung

Maximal ein Hauptstatus pro Pokémon gleichzeitig.

Eine Attacke definiert daher beispielsweise:

```json
{"kind":"status","status":"burn","chance":0.1}
```

und nicht eine eigene lokale Burn-Implementierung.

Puderattacken berücksichtigen zentral definierte Puderimmunitäten; insbesondere sind Pflanzen-Pokémon gegen entsprechende Puderattacken immun.

---

# 10. Genauigkeit

Bei einem Verfehlen gilt grundsätzlich:

- kein Schaden
- keine Treffer-Zusatzwirkung
- keine wirkungsabhängige Aggro

Mehrzielattacken prüfen Genauigkeit pro Ziel, sofern das Attackendesign nichts anderes festlegt.

Genauigkeitsmodifikationen sind multiplikativ und verwenden keine alten Genauigkeits-/Ausweichstufen.

Temporäre Genauigkeitswirkungen folgen heute grundsätzlich der **Drei-eigene-Aktionen-Regel** des betroffenen Pokémon.

---

# 11. Aggro

Aggro entsteht aus der tatsächlichen Wirkung:

- tatsächlicher Schaden
- tatsächlich wiederhergestellte KP
- tatsächlich angewendete taktische Wirkung
- zentral definierte feste Status-Aggro

Verfehlen oder immunisierte Effekte erzeugen keine Aggro für den ausgebliebenen Teil.

---

# 12. Flächenattacken

Bei Flächenattacken muss explizit festgelegt werden:

- welche Seite(n) getroffen werden
- ob der Anwender selbst getroffen wird
- ob Genauigkeit pro Ziel gewürfelt wird
- ob Volltreffer pro Ziel gewürfelt werden
- ob Status-/Zusatzeffekte pro Ziel separat geprüft werden

Beispiel: Blütenwirbel trifft alle anderen aktiven Pokémon, einschließlich Verbündeter, aber nicht den Anwender.

---

# 13. Volltreffer

Standard:

- Volltrefferchance 5 %
- Volltreffermultiplikator 1,5

Attacken mit erhöhter Volltrefferchance verwenden eine zentrale High-Crit-Regel, nicht jeweils eigene Formeln.

Für aktuell designte High-Crit-Attacken wurde 12,5 % als Referenz festgelegt.

Bei Mehrzielattacken wird pro Ziel separat gewürfelt.

---

# 14. Heilung

Skalierbare Heilung verwendet grundsätzlich den **Statuswert**.

Zentrale Kurve:

`R = Status / (75 + Status)`

Für natürlich auf 100 % begrenzte Heilwirkungen ist `100 × R` Prozent die Referenz. Reine Selbstheilungen können diesen Anteil auf die eigenen maximalen KP anwenden; abweichende Move-Gewichtungen müssen zentral dokumentiert sein.

`Synthesis / Synthese` ist die Referenz für eine reine statuswertbasierte Selbstheilung. Wetterabhängige Modifikationen laufen ausschließlich über das zentrale Wettersystem.

Drain-Attacken werden als **Hybridattacken** modelliert:

- verursachter Schaden → Angriff
- Rückheilung → Statuswert

Die gemeinsame Drain-Heilungsformel wird zentral kalibriert und darf nicht pro Drain-Attacke unterschiedlich erfunden werden. Bis diese Kalibrierung abgeschlossen ist, werden Bestandswerte nicht blind numerisch migriert.

Für Aggro zählt nur die tatsächlich wiederhergestellte KP-Menge.

---

# 15. Schutz und Team-Support

Alle-team-Effekte betreffen **alle vier Pokémon des eigenen Teams**.

Keine Reserve erwähnen oder simulieren.

Referenzen:

## Bodyguard

Alle vier Teammitglieder werden für ihre nächsten jeweils 3 eigenen Aktionen gegen neue Hauptstatuszustände immun. Vorhandene Statuszustände werden nicht geheilt.

## Sorgensamen

Alle vier Teammitglieder werden von Schlaf geheilt und erhalten anschließend für ihre nächsten jeweils 3 eigenen Aktionen Schlafimmunität.

## Rückenwind

Alle vier Teammitglieder erhalten für ihre nächsten jeweils 3 eigenen Aktionen die definierte Statuswert-basierte ATB-Beschleunigung.

---

# 16. Wetter – zentrale Mechanik

Wetter ist ein globaler Kampfzustand, keine lokale Eigenschaft eines Pokémon und **keine Statuswert-Skalierung der auslösenden Attacke**.

Verbindliches Architekturprinzip:

> **Quelle aktiviert Wetter-ID → zentrales Wettersystem übernimmt Stärke, Wirkung und Dauer.**

Regentanz und Sonnentag besitzen deshalb keine Status-Skalierung. Die Attacke setzt nur die passende `weather_id`.

Für normales Timeflow-Wetter gilt aktuell:

- genau ein globales Wetter gleichzeitig
- anderes Wetter ersetzt das aktive Wetter
- ein kontinuierlicher Wetter-Zeitbalken
- Standarddauer 50 Sekunden aktive Kampfzeit
- Wetterzeit pausiert während pausierter Spielerentscheidungen
- gleiches aktives Wetter kann nicht erneut ausgelöst oder erneuert werden
- Wetterdauer und Wetterwirkung liegen zentral im Wettersystem

Wettermodifikatoren werden zentral in Schadens-/Effektsysteme integriert und nicht pro Attacke dupliziert.

---

# 17. Auflade-, Nachlade- und mehrteilige Attacken

Solche Mechaniken werden als zentrale Effektarten modelliert.

Beispiele:

- Solarstrahl: Aufladen → später automatischer Abschuss; Sonne kann Aufladen überspringen
- Hyperstrahl / Gigastoß: nach erfolgreichem Treffer nächste eigene Aktionsmöglichkeit als Nachladen verbrauchen
- Blättertanz: mehrere erzwungene eigene Aktionen, anschließend Verwirrung
- Bindung: 4–5 eigene Aktionen des Ziels mit periodischem Schaden

Keine dieser Mechaniken darf nur als Freitext in der Datenbank stehen, ohne Runtime-Verhalten.

---

# 18. Rückstoß vs. Zurückschrecken

Begriffe strikt trennen:

**Rückstoß** = Anwender erleidet selbst Schaden aufgrund seiner Attacke.

Beispiele: Bodycheck, Flammenblitz, Wellentackle.

**Zurückschrecken / Flinch** = Ziel erhält eine ATB-Manipulation. In RPG-Pokémon verwendet dies die zentrale ATB-Knockback-Mechanik, wie bei Biss.

Beispiele: Biss, Feuerzahn, Luftschnitt.

Nicht „Rückstoß“ nennen, wenn Zurückschrecken gemeint ist.


# 18.1 Pflicht: gemeinsame zentrale Zustände bei Attacken-Wechselwirkungen

Wenn eine Attacke einen Zustand erzeugt, auf den eine andere Attacke reagieren kann, wird dieser Zustand **zentral** modelliert und von beiden Attacken referenziert.

Beispielprinzip:

> `Schaufler` setzt später einen zentralen Zustand „unter der Erde“; `Erdbeben` prüft genau diesen Zustand und reagiert darauf.

Nicht erlaubt:

- unabhängige lokale Flags pro Attacke für denselben Zustand
- Wechselwirkungen nur als Beschreibung/Freitext ohne Runtime-Vertrag
- dieselbe Mechanik mehrfach mit leicht unterschiedlichen IDs nachbauen

Für einen gemeinsamen Zustand müssen mindestens festgelegt sein:

- Zustands-ID und Bedeutung
- wer betroffen ist
- Quelle/Anwender, falls relevant
- Dauer/Verbrauch
- Eintritts- und Austrittsbedingungen
- welche Attacken/Systeme darauf reagieren
- Verhalten bei Kampfunfähigkeit, Ende des Kampfes und Konflikten
- erforderliche Interaktions-/Regressionstests

---

# 19. Pflicht: echte Verhaltenstests für Sondermechaniken

Für reine Standardschadensattacken genügt ein einfacher Daten-/Schadenstest.

Für jede Sondermechanik müssen echte automatisierte Verhaltens-/Headless-Tests vorgesehen werden.

Mindestens je nach Mechanik prüfen:

- richtiger Trigger
- richtige Ziele
- richtige Stärke
- richtige Chance
- richtige Dauer
- korrektes Herunterzählen
- korrekter Verbrauch
- Immunitäten
- Miss-Fälle
- Mehrziel-Interaktionen
- Aggro
- Statuskonflikte
- Wetter-/ATB-Interaktionen

Ein Daten-Audit, das nur bekannte Mechanik-IDs prüft, reicht **nicht**.

Unbekannte Mechanik-IDs dürfen in Entwicklung/Tests nicht stillschweigend ignoriert werden.

---

# 20. Leere Attacken-Schablone

```json
{
  "schema_version": 3,
  "id": "example_move",
  "name": "Beispielattacke",
  "description": "Spielerlesbare Beschreibung mit kanonischen Attributnamen.",
  "emoji": "✨",
  "type": "normal",
  "category": "status",
  "power": null,
  "accuracy": 100,
  "original_pp": 20,
  "rpg_ap": 5,
  "target": "enemy_highest_aggro",
  "area": false,
  "contact": false,
  "priority_reference": 0,
  "opening_phase": false,
  "effects": [],
  "status_scaling": "none",
  "aggro": {
    "from_damage": false,
    "from_status": true,
    "from_healing": false
  },
  "special_rules": [],
  "required_behavior_tests": []
}
```

---

# 21. Designphase: erst verständlich entscheiden, dann technisch festschreiben

Für offene oder unvollständige Attacken wird zuerst auf Spieler-/Designebene gearbeitet.

Vor einer technischen Datendefinition soll die Attacke verständlich beschrieben werden mit:

- deutschem Namen
- Typ
- Kategorie
- Original-Stärke, Genauigkeit und Original-PP, soweit relevant
- Grundidee der Originalattacke
- wichtigen Original-Sondermechaniken
- vorgeschlagener Timeflow-Übersetzung

In dieser Phase:

- keine Programmierung
- keine GitHub-Änderungen
- kein Implementierungs-Handoff
- keine unnötig großen technischen Datenstrukturen

Erst nach inhaltlicher Freigabe gilt das Attackendesign als beschlossen und darf in ein technisches Handoff überführt werden.

---

# 22. Technischer Vertrag nach der Designfreigabe

Nach Freigabe muss eine Sonderattacke so vollständig beschrieben sein, dass die Implementierung keine spielrelevante Entscheidung improvisieren muss.

Je nach Attacke festhalten:

- zentrale Effektarten / Mechanik-IDs
- Zielauflösung und Flächenwirkung
- Statuswert-Skalierung
- Aggroquellen
- Dauer und Herunterzählen
- gemeinsame zentrale Zustände
- Wechselwirkungen mit anderen Attacken
- Miss-/Immunitätsverhalten
- Spielertext und benötigte Laufzeitwerte im Tooltip
- UI-/Statusanzeige
- Registry-/Contract-Anforderungen
- echte Verhaltens- und Regressionstests

Bestehende zentrale Mechaniken werden erweitert oder wiederverwendet; sie werden nicht attackenspezifisch dupliziert.

---

# 23. Wann eine Attacke wirklich als implementiert gilt

Eine Attacke ist nicht schon deshalb implementiert, weil eine Zeile in der Datenbank existiert.

Für „vollständig implementiert“ müssen – soweit für die Attacke relevant – gemeinsam stimmen:

- Attacken-Datenbank
- zentrale Runtime/Effektauflösung
- zentrale Registry/Contracts
- Status-/Wetter-/ATB-/Aggro-Integration
- Spielerbeschreibung und dynamische Tooltips
- Ziel- und Mehrzielauflösung
- UI-Anzeige
- automatisierte Verhaltenstests
- Regressionstests bestehender Mechaniken
- tatsächlicher Hauptspielpfad, der diese Runtime benutzt

Unvollständige Runtime-Unterstützung muss als solche gelten und darf nicht nur wegen vorhandener Daten als „fertig“ markiert werden.

Wird bei der Abschlussprüfung ein Fehler gefunden, wird er behoben und erneut getestet, bevor die Attacke als abgeschlossen gilt.

---

# 24. Arbeitsablauf

1. Aktuellen Datenbank- **und Runtime-Stand** prüfen: vollständig, teilweise oder fehlend.
2. Prüfen, ob die Attacke bereits zentral designt ist. Wenn ja: **wiederverwenden, nicht redesignen**.
3. Originaldaten aus geeigneter aktueller Hauptspielquelle prüfen. `Tera Blast / Tera-Ausbruch` ignorieren.
4. Typ, Stärke, Genauigkeit, PP, Ziel, Kontakt und Originaleffekt erfassen.
5. PP in RPG-AP übersetzen.
6. Zielregel für das 4v4-Aggro-System festlegen.
7. Originaleffekt in zentrale RPG-Mechanik übersetzen.
8. Jede Wirkungskomponente klassifizieren: direkter Schaden → Angriff; quantitativ skalierbare nicht-schädigende Wirkung → grundsätzlich Statuswert; binäre/feste/zentral geregelte Ausnahme ausdrücklich dokumentieren.
9. Standarddauer 3 eigene Aktionen verwenden, sofern kein begründeter Sonderfall vorliegt.
10. Spielerbeschreibung formulieren: reale Attribute nennen, keine Roh-Multiplikatoren oder technischen IDs.
11. Emoji festlegen.
12. Aggroquellen definieren.
13. Verhaltenstests für Sondermechaniken definieren.
14. Wording-Audit durchführen: In `description` dürfen insbesondere keine `×`-Multiplikatoren, `incoming/outgoing_damage`-Begriffe, `ATB-Zyklus ×...`, englische Typ-IDs oder technische Effekt-IDs stehen.
15. Prüfen, dass dynamische Prozentwerte nicht als erfundene feste Zahlen in der Beschreibung stehen; sie werden zur Laufzeit berechnet.
16. Prüfen, dass keine Reserve-/Wechselannahme enthalten ist.
17. Prüfen, dass keine globale Regel lokal dupliziert wurde.

---

# 25. Grundsatz für zukünftige Änderungen

Globale Änderungen zuerst in `RPG_POKEMON_KAMPFREGELN_MASTER_V5.md` eintragen und anschließend hier spiegeln.

Neue Chats sollen ausschließlich diese V5-Fassung als Attacken-Designquelle verwenden.
