# Kampfhintergründe – Format und Systematik

Der aktive Kampfbereich ist **632 × 216 px** groß. Neue Hintergründe sollen deshalb immer exakt dieses Seitenverhältnis verwenden.

## Empfohlenes Produktionsformat

- Arbeits-/Exportgröße: **1264 × 432 px** (2× Spielauflösung)
- Seitenverhältnis: **79:27** (ca. 2,926:1)
- Geeignete Formate: `.svg`, `.webp` oder `.png`
- Im Spiel werden die Bilder auf **632 × 216 px** dargestellt.
- Keine Schrift, Rahmen oder HUD-Elemente in das Bild malen.

## Bildaufbau

- Der mittlere Bereich soll eher ruhig bleiben, damit Kampfanimationen lesbar sind.
- Links und rechts dürfen mehr Umgebungsdetails liegen.
- Wichtige Motive nicht direkt an den Rand setzen; dort stehen Pokémon und Statuskarten.
- Perspektive möglichst als breite, leicht seitliche Kampffläche anlegen.
- Helligkeit und Kontrast so wählen, dass helle und dunkle Pokémon erkennbar bleiben.

## Landschaften

Die 18 festen Landschaftsbilder liegen gesammelt unter:

`assets/battle_backgrounds/landscapes/`

Die verbindlichen Dateinamen stehen dort in `README.md`.

## Einbindung

Die Battle-Demo lädt standardmäßig:

`res://assets/battle_backgrounds/meadow_placeholder.svg`

Das aktive UI-Script besitzt außerdem `set_battle_background(path)`, sodass später pro Region, Route, Gebäude oder Wetterlage ein anderer Hintergrund gesetzt werden kann, ohne das Kampfsystem umzubauen.
