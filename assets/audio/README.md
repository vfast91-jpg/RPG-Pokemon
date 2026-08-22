# Audio – Pokémon Timeflow

Dieser Ordner ist die zentrale Ablage für Musik und Soundeffekte.

## Struktur

- `music/loops/` – Hintergrundmusik, die während Menü, Route oder Kampf in Schleife läuft.
- `music/stingers/` – kurze musikalische Ereignisse wie Sieg, Level-Up oder Entwicklung.
- `sfx/` – kurze Soundeffekte für Attacken, Treffer, UI und andere Spielaktionen.

## Bevorzugtes Format

Für Musik bevorzugt `.ogg`. Godot kann OGG direkt importieren und Loop-Punkte sauber verwalten.

Soundeffekte können später ebenfalls als `.ogg` oder bei sehr kurzen Effekten als `.wav` verwendet werden.

## Wichtig

Audio-Dateien werden zunächst nur hier abgelegt. Die endgültige Zuordnung, Lautstärke, Übergänge und Loop-Punkte werden anschließend zentral im Audiosystem des Spiels eingerichtet.
