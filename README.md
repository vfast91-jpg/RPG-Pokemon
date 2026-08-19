# RPG-Pokemon – Godot Demo 0.3

Die Demo enthält jetzt die begehbare Route **und einen Pikachu-Testkampf**.

## Öffnen

1. Auf GitHub **Code → Download ZIP**.
2. ZIP vollständig entpacken.
3. In Godot **`project.godot`** importieren.
4. **▶ Projekt ausführen**.

Wenn noch eine ältere Version erscheint, hast du wahrscheinlich noch einen alten lokalen Projektordner geöffnet.

## Steuerung Oberwelt

- **WASD / Pfeiltasten** – laufen
- **E / Leertaste** – interagieren

## Pikachu-Demokampf

Im westlichen hohen Gras steht jetzt ein sichtbares Pikachu.

Daneben befindet sich ein **Kampf-Testterminal**:

- Anzahl eigener Pikachus: 1–4
- Anzahl wilder Pikachus: 1–4
- Level jedes einzelnen Pikachus: 1–100
- Preset: 4v4 auf Level 15
- Preset: 4v4 mit Level 5 / 15 / 30 / 50

Sprich das Pikachu an, um mit der aktuellen Konfiguration zu kämpfen.

Der Kampf enthält:

- KP-Leisten
- ATB-Leisten
- Wangenrubbler
- Ruckzuckhieb
- Heuler
- Paralyse
- Angriffsstufen
- kleine Treffer-/Bewegungsanimationen
- Gegner-KI
- Sieg- und Niederlagebildschirm
- sichere Rückkehr zur Route nach dem Kampf

Die Kampfdaten liegen in `data/PIKACHU_DEMO_ALL_IN_ONE.json`.

## Assets

- Pikachu: `assets/Pikachu.png`
- Tileset: `assets/punyworld-overworld-tileset_0.png`
- weitere Lizenz- und Quellenhinweise: `ASSET_CREDITS.md`
