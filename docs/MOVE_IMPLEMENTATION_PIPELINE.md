# Attacken-Implementierungspipeline

Neue Attacken sollen nicht mehr an mehreren UI- und Runtime-Stellen unabhängig voneinander „bekannt gemacht“ werden.

## Ablauf

1. Attacke einmal zentral definieren.
2. `MoveContract` kompiliert V4-Feldnamen (`rpg_ap`, `opening_phase`, `priority_reference`, `effects`) in die bestehende Runtime-Form.
3. `MoveContract` prüft Pflichtfelder, Zielregel, Typ, Kategorie, RPG-AP, Chancen, Dauer, Status-IDs, Mechanik-IDs, Aggrovertrag und Spielertext.
4. `MoveEffectRegistry` ist die zentrale Liste aller erlaubten Mechaniken. Eine neue Mechanik muss dort ihren Runtime-Status und ihre UI-Oberflächen explizit deklarieren.
5. Eine unbekannte Mechanik ist ein Fehler. Sie wird nicht still ignoriert.
6. Strict/V4-Attacken mit Fehlern werden zur Laufzeit auf `runtime_supported=false` gesetzt und dadurch nicht als normale Attacke angeboten.
7. `MovePresenter` erzeugt kanonische Spielerbegriffe. Technische Multiplikatoren und IDs dürfen nicht in Tooltip oder Detailanzeige gelangen.
8. Die GitHub-Action `move_contract_test.gd` prüft bei jedem Push nach `main` das komplette aktuelle Attackenpaket sowie den Vertrag selbst.

## Verbindliche Skalierungsentscheidung pro Wirkungskomponente

Für jede neue oder migrierte Attacke wird **jede Wirkungskomponente einzeln** klassifiziert. Die Attackenkategorie allein entscheidet nicht über den verwendeten Attributswert.

Grundregel:

- direkter KP-Schaden einer Attacke → **Angriff**
- quantitativ skalierbare nicht-schädigende Wirkung → grundsätzlich **Statuswert**
- feste, binäre oder zentral anderweitig geregelte Mechanik → keine automatische Status-Skalierung

Dadurch dürfen Hybridattacken gleichzeitig mehrere Quellen verwenden. Bei Drain-Attacken wird beispielsweise der Schaden über Angriff berechnet, während die skalierbare Rückheilung eine Statuswert-Komponente ist.

Nicht automatisch Statuswert-basiert sind insbesondere die bloße Anwendung standardisierter Hauptstatuszustände, feste Regelzustände wie Verhöhner/Zugabe/Aussetzer, Feldgefahren, die feste zentrale Zurückschrecken-Wirkung, Schutzschild als binärer Block sowie Wetteraktivierung. Eine ausdrücklich definierte zentrale Sonderregel hat immer Vorrang.

Die aktive Statuskurve bleibt zentral in `data/rules/status_scaling.json` definiert (`R = Status / (75 + Status)`). Einzelne Attacken dürfen keine konkurrierende Statusformel hartkodieren. Für Drain-Rückheilung ist die Zuständigkeit Statuswert bereits verbindlich; die gemeinsame numerische Drain-Kalibrierung wird vor der Bestandsmigration einmal zentral festgelegt.

## Zentrale Flächenschadensregel

Jede **schadende Flächen-/Mehrzielattacke** verwendet die zentrale Timeflow-Flächenschadensformel auf den **final berechneten Schaden pro Ziel**:

- 1 tatsächlich betroffenes Ziel → **100 %**
- 2 tatsächlich betroffene Ziele → **75 %** je Ziel
- 3 tatsächlich betroffene Ziele → **60 %** je Ziel
- 4 oder mehr tatsächlich betroffene Ziele → **50 %** je Ziel

Die Zielzahl wird für eine Attackenauflösung beim ersten Schadentreffer festgeschrieben. Ein frühes K. o. innerhalb derselben Attacke darf den Multiplikator für spätere Ziele derselben Attacke nicht erhöhen. Trefferprüfung, Volltreffer, Typenwirkung, Immunität und Zusatzeffekte bleiben weiterhin pro Ziel getrennt.

Technische Quelle ist ausschließlich `scripts/battle/area_damage_rules.gd`; der finale Schadens-Hook sitzt in `scripts/battle_demo_endgame_v2.gd`. Einzelne Familien- oder Attacken-Layer dürfen **keine eigene konkurrierende Flächenschadensformel** einbauen.

Eine absichtliche Vollschaden-Ausnahme muss im Attackenvertrag ausdrücklich `runtime.timeflow_full_spread_power = true` tragen und durch einen Verhaltenstest abgesichert sein. Bedingte Flächenattacken, die im Grundzustand Einzelziel sind, können zusätzlich `runtime.central_area_damage_scaling = true` tragen; sobald sie zur Mehrzielattacke werden, greift dieselbe zentrale Formel.

`tests/area_damage_scaling_test.gd` auditiert bei jedem Push nach `main` alle aktuell geladenen schadenden Flächenattacken, bekannte Vollschaden-Ausnahmen, bedingte Flächenverträge und die Multiplikator-Tabelle.

## Wann eine Attacke strikt geprüft wird

Die aktive Integration schaltet den strikten Vertrag automatisch ein, sobald mindestens eines davon vorhanden ist:

- `runtime.strict_contract = true`
- `required_behavior_tests`
- `rpg_ap`
- `effects`

Alte Schema-v3-Runtime-Daten bleiben kompatibel, werden aber weiterhin auf unbekannte Mechaniken und kaputte Grundstruktur geprüft.

## Neue Mechanik hinzufügen

Eine neue Mechanik ist erst fertig, wenn alle vier Punkte existieren:

- Runtime-Ausführung
- Tooltip-/Attackeninfo-Darstellung
- Statuskarten-/Detailentscheidung (`status_card=true/false`)
- automatisierte Verhaltenstests für echte Sondermechaniken

Danach wird die Mechanik in `MoveEffectRegistry.EFFECTS` eingetragen. Ohne Registry-Eintrag blockiert der Vertrag die Attacke.

## Spielertext

Attributänderungen werden sichtbar ausschließlich als

- Angriff
- Verteidigung
- Statuswert
- Geschwindigkeit
- Genauigkeit
- KP
- RPG-AP

ausgegeben. Interne IDs wie `incoming_damage_mod` oder Rohtexte wie `ATB-Zyklus ×0,8` sind im Spielertext verboten.

## Verhaltenstests

Eine reine Standardschadensattacke darf `required_behavior_tests: []` besitzen. Jede Sondermechanik benötigt eine nichtleere Testliste. Je nach Mechanik gehören dazu Trigger, Ziele, Stärke, Chance, Dauer, Herunterzählen, Verbrauch, Immunitäten, Miss-Fälle, Mehrziel-Interaktionen, Aggro, Statuskonflikte und Wetter-/ATB-Interaktionen.

## Wichtig für Implementierungs-Chats

Bei jedem neuen Attackenpaket zuerst den Vertrag und das Effektregister prüfen. Wenn eine Mechanik noch nicht im Register existiert, nicht lokal in einer einzelnen Attacke improvisieren. Stattdessen die Mechanik einmal zentral ergänzen, ihre UI-Darstellung festlegen und ihre Verhaltenstests hinzufügen. Erst danach die Attacken des Pakets freigeben.
