# RPG Pokémon – Pokémon-Familien-Implementierungspipeline V1
## Verbindliche Anleitung für neue Implementierungs-Chats

**Stand:** 2026-08-22  
**Status:** Verbindliche Implementierungsanleitung nach abgeschlossener Excel-Designphase

---

# 0. Zweck

Diese Anleitung ist für den Arbeitsmodus gedacht, in dem die Pokémon- und Attacken-Excel-Datenbanken bereits fertig designt sind.

Der Nutzer soll in einem neuen Chat nur noch eine Pokémon-Familie nennen. Der Chat übernimmt danach selbstständig die komplette technische Implementierung der Familie inklusive aller von ihr benötigten Attacken, die im Spiel noch nicht vollständig implementiert sind.

**Wichtig:** Dieser Ablauf ist eine **Implementierungspipeline, keine neue Designrunde**. Fertige Excel-Entscheidungen werden umgesetzt und nicht neu erfunden.

---

# 1. Harte Branch-Regel

Es wird ausschließlich auf Git-Branch `main` gearbeitet.

Verbindlich:

- niemals einen neuen Branch erstellen
- niemals auf einem anderen Branch weiterarbeiten
- `WORKFLOW.md` beachten
- den aktuellen `main`-Stand unmittelbar vor dem ersten Schreibvorgang erneut lesen
- bei längerer Arbeit oder erkennbaren Paralleländerungen den aktuellen `main`-SHA vor dem nächsten Schreibblock erneut prüfen
- parallele Änderungen auf `main` niemals mit älteren Dateiständen überschreiben

---

# 2. Quellenpriorität

Bei Widersprüchen gilt diese Reihenfolge:

1. `RPG_POKEMON_KAMPFREGELN_MASTER_V4.md`
2. `POKEMON_SPECIES_DESIGN_GUIDE_V4.md`
3. `RPG_POKEMON_ATTACKEN_DESIGN_GUIDE_V4.md`
4. die **jeweils aktuellste verfügbare Pokémon-Excel-Datenbank**
5. die **jeweils aktuellste verfügbare Attacken-Excel-Datenbank**
6. `docs/MOVE_IMPLEMENTATION_PIPELINE.md`
7. aktueller Runtime-, Registry-, Presenter-, Daten- und Teststand auf `main`
8. ältere V1/V2/V3-Dateien nur als historische/technische Kompatibilitätsquelle

Für die beiden Excel-Datenbanken ist jeweils die neueste verfügbare Fassung zu verwenden. Bei versionierten Dateinamen gilt zuerst die höchste Versionsnummer, bei Gleichstand das neueste Datum.

Typische Dateinamen:

- `Pokemon_Datenbank_Gen1_AKTUALISIERT_*.xlsx`
- `Attacken_Datenbank_AKTUALISIERT_*.xlsx`

Nach Abschluss der Designphase werden die Excel-Dateien für einen normalen Implementierungsauftrag **als read-only Designquelle** behandelt. Der Implementierungs-Chat ändert keine Designwerte stillschweigend. Eine Excel-Final-Synchronisierung erfolgt nur, wenn sie ausdrücklich Bestandteil des jeweiligen Arbeitsauftrags ist oder eine dafür vorgesehene aktuelle Quelldatei beschreibbar vorliegt.

---

# 3. Familienname aus dem Prompt auflösen

Der im Prompt genannte Name darf der deutsche Anzeigename oder die technische `species_id` eines beliebigen Familienmitglieds sein.

Vorgehen:

1. In der neuesten Pokémon-Datenbank die passende Spezies-Spalte finden.
2. `Speziesfamilien-ID` auslesen.
3. Alle Spezies mit derselben `Speziesfamilien-ID` einsammeln.
4. Die Entwicklungsreihenfolge aus den Entwicklungsfeldern bestimmen.
5. Bei verzweigten Familien alle zur Familien-ID gehörenden Entwicklungszweige einbeziehen.

Die Familie wird immer als **ein gemeinsamer Implementierungsauftrag** behandelt.

---

# 4. Pflicht-Audit vor jeder Implementierung

Bevor Code oder Runtime-Daten geändert werden, wird automatisch ein Ist-Audit erstellt.

Mindestens prüfen:

- alle Familienmitglieder und ihre vollständigen Speziesdaten aus der Pokémon-Excel
- Level-Up-, Entwicklungs-/Relearn- und vollständige TM-/VM-Lernlisten jeder Stufe
- alle daraus referenzierten Attacken-IDs
- `Tera Blast / Tera-Ausbruch` vollständig ignorieren
- welche Spezies bereits auf `main` vorhanden sind
- welche Attacken bereits zentral vorhanden sind
- welche Attacken zwar Daten besitzen, aber noch keine vollständige Runtime-Unterstützung haben
- welche Attacken vollständig fehlen
- welche benötigten Mechaniken bereits zentral in Runtime/Registry/Presenter existieren
- welche neue oder unvollständige Mechanik zentral ergänzt werden muss
- welcher Datenbank-Manifest-/Loader-Pfad im **aktuellen Hauptspiel tatsächlich aktiv** ist

Jede Attacke wird genau einer Kategorie zugeordnet:

- **vollständig vorhanden → unverändert wiederverwenden**
- **Daten vorhanden, Runtime unvollständig → zentral vervollständigen**
- **Design vorhanden, Implementierung fehlt → exakt nach Excel/Handoff implementieren**
- **vollständig fehlend → aus der fertigen Attacken-Excel als neue zentrale Attacke übernehmen**

Ein vorhandener Datenbankeintrag allein bedeutet niemals „implementiert“.

---

# 5. Pokémon-Daten übernehmen

Für jedes Familienmitglied werden die Werte aus der Pokémon-Excel ohne Neudesign in das aktuelle kanonische Runtime-Datenformat von `main` übertragen.

Mindestens korrekt übernehmen:

- Schema-Version
- `species_id`
- Pokédex-Nummer
- Anzeigename
- Kategorie
- `asset_id`
- Größe und Gewicht
- Typ 1 / Typ 2
- Basis-KP
- Basis-Angriff
- Basis-Verteidigung
- Basis-Statuswert → technisches Feld `special`, falls die Runtime dieses weiterhin verwendet
- Basis-Geschwindigkeit
- RPG-Basiswertsumme / Referenzwerte, soweit das aktive Schema sie führt
- EP-Kurve
- Basis-EP-Ausbeute
- Fangrate
- Speziesfamilien-ID / Familien-Fangrate
- verpflichtende Entwicklung einschließlich Level, Ziel und Methode
- Level-Up-Lernliste
- Entwicklungs-/Relearn-Attacken
- vollständige TM-/VM-Lernliste dieser Entwicklungsstufe
- Tags/Notizen nur soweit sie im aktuellen Runtime-Schema vorgesehen sind

Dabei gilt:

- keine Attackenmechanik pro Pokémon duplizieren
- Attacken ausschließlich über zentrale Attacken-IDs referenzieren
- keine TM-Kompatibilität aus anderen Entwicklungsstufen ableiten
- keine fehlenden Werte aus Erinnerung ergänzen
- Asset-Pfade gegen den aktuellen `assets/monsters`-Bestand prüfen; fehlende Bilder nicht erfinden

---

# 6. Attacken automatisch mitimplementieren

Aus allen Lernlisten der Familie wird die vollständige Menge benötigter Attacken-IDs gebildet.

Für jede Attacke:

## Bereits vollständig implementiert

Nur wiederverwenden. Keine zweite Definition, keine Familienkopie, kein Redesign.

## Daten vorhanden, Runtime unvollständig

Die zentrale Runtime vervollständigen. Falls nötig:

- Effektregister erweitern
- gemeinsame Mechanik zentral implementieren
- Presenter/Tooltip ergänzen
- Status-/Feld-/Wetter-/ATB-/Aggro-Anbindung ergänzen
- Verhaltenstests ergänzen

## Noch nicht implementiert

Die fertige Attacken-Excel ist die Designquelle. Zu übernehmen sind insbesondere:

- `id`
- Name
- Spielerbeschreibung
- Typ
- Kategorie
- Stärke/Basiswirkung
- Genauigkeit
- strukturierte Effekte
- Statuswert-Skalierung
- Original-PP / Basis-RPG-AP / tatsächliche RPG-AP
- AP-Abweichungsgrund
- Erholungsmodifikator
- Zielart
- Kontakt / Fläche
- Prioritätsreferenz
- Eröffnungsphase
- Aggroquellen
- Mehrfachtreffer / Aufladen / Kanalisierung / Dauer
- Tags / Spezialregeln
- Emoji

Wenn für die Attacke im Tabellenblatt `Compiler-Handoff` ein Eintrag existiert, ist dieser technische Handoff zusätzlich verbindlich, insbesondere für:

- zentrale Mechanik
- neue Systemanforderung
- `required_behavior_tests`
- UI-/Presenter-Vertrag
- Freigabekriterium

Keine spielrelevante Entscheidung darf während der Implementierung neu erfunden werden.

---

# 7. Zentrale Mechanik statt Pokémon-Sonderlösung

Neue allgemeine Mechaniken werden zentral gebaut.

Bevorzugte Orte sind die aktuell auf `main` vorhandenen zentralen Kampfmodule, insbesondere:

- `scripts/battle/move_contract.gd`
- `scripts/battle/move_effect_registry.gd`
- `scripts/battle/move_presenter.gd`
- weitere gemeinsame Module unter `scripts/battle/`

Verboten ist eine Pokémon-spezifische Sonderkopie, wenn dieselbe Mechanik allgemein wiederverwendbar ist.

Ein neuer Effekt-/Mechaniktyp ist erst fertig, wenn – soweit relevant – gemeinsam vorhanden sind:

- Runtime-Ausführung
- Registry-/Contract-Eintrag
- Zielauflösung
- Dauer/Verbrauch/Herunterzählen
- Statuswert-Skalierung
- Aggro
- Miss-/Immunitätsverhalten
- UI-/Tooltip-/Statuskarten-Darstellung
- echte Verhaltenstests

Unbekannte Mechaniken dürfen nicht still ignoriert werden.

---

# 8. Aktiven Hauptspielpfad wirklich aktualisieren

Es reicht nicht, neue JSON-Dateien anzulegen.

Der Implementierungs-Chat muss nachweisen, dass der aktuelle Hauptspielpfad die neuen Daten tatsächlich lädt.

Dazu mindestens prüfen und bei Bedarf aktualisieren:

- aktives kanonisches Datenbank-Manifest
- Species-Dateiliste
- Move-Dateiliste
- Meta-/Root-/Familienregistrierung
- `species_count`
- `move_count`
- `route_root_count`, falls betroffen
- tatsächlich vom Loader verwendeter Manifestpfad
- relevante Datenbank-/Runtime-Brücke

Wenn mehrere alte Manifest-Versionen im Repository liegen, darf nicht automatisch die höchste Dateinummer als aktiv angenommen werden. Entscheidend ist der Pfad, den der aktuelle `main`-Runtimecode wirklich verwendet.

---

# 9. Verbindliche Timeflow-Regeln, die niemals zurückgebaut werden dürfen

Während der Familienimplementierung dürfen keine historischen Pokémon-Regeln wiedereingeführt werden.

Insbesondere:

- maximal vier Pokémon pro Team, keine Reserve
- kein Kampfwechsel-/Nachrücksystem
- unbegrenztes Attackenwissen, kein Vier-Attacken-Limit
- verpflichtende automatische Entwicklungen gemäß Datenbank
- zentrale Aggro-Zielregel für offensive Einzelziele
- klassische Priorität wirkt nicht im normalen ATB-Kampf
- Runde-0-/Eröffnungsphase ist ausdrücklich datengetrieben
- RPG-AP sind Zeitkosten und keine verbrauchbare Ressource
- temporäre Effekte standardmäßig drei eigene Aktionen des Betroffenen, sofern die Attacke nichts anderes festlegt
- kein allgemeines Item-/Beeren-/Held-Item-System
- keine Terakristallisierung
- `Tera Blast / Tera-Ausbruch` nicht implementieren
- Spielertexte verwenden Angriff, Verteidigung, Statuswert, Geschwindigkeit, Genauigkeit und KP statt technischer IDs/Rohmultiplikatoren

---

# 10. Tests sind Teil der Implementierung

Eine Familie ist nicht fertig, solange nur Daten und Code geschrieben wurden.

Mindestens erforderlich:

1. Datenbank-/Familien-Integrationstest
   - alle Familienmitglieder vorhanden
   - korrekte Familien-ID
   - korrekte Entwicklungsfolge
   - exakte TM-Anzahl und TM-IDs je Entwicklungsstufe
   - kein Tera-Ausbruch
   - alle referenzierten Attacken-IDs auflösbar

2. MoveContract-/Registry-Prüfung
   - jede neue/angepasste Strict-V4-Attacke fehlerfrei
   - `runtime_supported=true` erst nach echter Unterstützung

3. Verhaltenstests
   - alle im `Compiler-Handoff` bzw. `required_behavior_tests` geforderten Tests
   - echte Mechaniktests, nicht nur ID-/Schema-Prüfung

4. Regressionstests
   - zentrale Mechanik darf bestehende Attacken nicht brechen

5. Hauptspiel-/Loader-Test
   - neue Familie und Attacken werden vom tatsächlich aktiven Pfad geladen

6. Godot Headless / CI
   - vorhandene zentrale GitHub-Action auf `main` muss die relevanten Tests ausführen
   - neue relevante Testdateien müssen in die zentrale Headless-Suite aufgenommen werden
   - wenn kein lokaler Godot-Lauf möglich ist, den zugehörigen GitHub-Actions-Lauf des neuen `main`-Commits prüfen

Fehlschlag bedeutet: Fehler beheben und erneut prüfen. Nicht „fast fertig“ melden.

---

# 11. Definition of Done

Die Pokémon-Familie darf erst als **vollständig implementiert** gemeldet werden, wenn alles Folgende stimmt:

- alle Familienmitglieder sind im aktiven Hauptspiel-Datenpfad vorhanden
- alle Spezieswerte entsprechen der neuesten Pokémon-Excel
- alle Entwicklungen funktionieren gemäß Datenbank
- alle Level-/Entwicklungs-/TM-Attacken referenzieren gültige zentrale Attacken
- alle bereits vorhandenen Attacken wurden wiederverwendet statt dupliziert
- alle fehlenden oder unvollständigen Attacken sind vollständig implementiert
- neue Mechaniken sind zentral statt Pokémon-spezifisch umgesetzt
- Registry/Contract/Presenter/UI sind vollständig
- alle benötigten Verhaltenstests existieren und sind grün
- relevante Regressionstests sind grün
- Godot-Headless-/CI-Prüfung ist grün
- Hauptspiel lädt wirklich die neuen Daten
- keine neue Attacke ist fälschlich als `runtime_supported=true` markiert
- keine parallele `main`-Änderung wurde überschrieben

---

# 12. Umgang mit echten Blockern

Der Implementierungs-Chat soll selbstständig arbeiten und keine unnötigen Rückfragen stellen.

**Kein Rückfragen-Grund:**

- eine Mechanik ist neu, aber in Excel/Handoff eindeutig spezifiziert → zentral implementieren
- eine Attacke fehlt im Runtimebestand, ist aber in der fertigen Excel vollständig beschrieben → implementieren
- bestehende Architektur ist unübersichtlich → aktuellen Hauptpfad ermitteln und sauber integrieren

**Echter Blocker:**

Nur wenn eine spielrelevante Entscheidung in den verbindlichen Quellen tatsächlich fehlt oder sich widerspricht und nicht technisch eindeutig auflösbar ist, darf die Familie nicht durch Raten abgeschlossen werden.

Dann:

- alle eindeutig möglichen Arbeiten trotzdem erledigen
- den exakten fehlenden/konfligierenden Datenpunkt nennen
- nichts erfinden
- nicht behaupten, die Familie sei vollständig fertig

---

# 13. Abschlussmeldung an den Nutzer

Die Abschlussmeldung bleibt kurz und enthält nur:

- implementierte Familienmitglieder
- neu implementierte Attacken
- wiederverwendete Attacken in zusammengefasster Form
- neu/zentral ergänzte Mechaniken
- Test-/CI-Status
- finalen `main`-Commit-SHA
- echte Restblocker, falls vorhanden

Keine lange Wiederholung aller Excel-Inhalte.

---

# 14. Standardprompt für neue Chats

Der Standardprompt lautet:

> Implementiere Familie Bisasam vollständig nach `docs/POKEMON_FAMILY_IMPLEMENTATION_PIPELINE.md` auf `main`.

Für die nächste Familie wird nur das einzelne Wort **Bisasam** ersetzt.
