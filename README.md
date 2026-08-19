# RPG-Pokemon – Godot Exploration Demo 0.2

Die Oberwelt ist jetzt auf ein **klassisches Tile-/Grid-System** umgestellt. Die Grafik kommt aus dem hochgeladenen Puny-World-Tileset und wird intern als 16×16-Raster verwendet und im Spiel pixelgenau 2× dargestellt.

## So öffnest du die aktuelle Version

1. Auf GitHub **Code → Download ZIP**.
2. ZIP vollständig entpacken.
3. Godot öffnen.
4. **Importieren** wählen.
5. Im neuen Ordner **`project.godot`** auswählen.
6. Projekt öffnen und **▶ Projekt ausführen** drücken.

Wenn noch die alte frei gezeichnete Karte oder die dunkle technische ATB-Testkarte erscheint, ist noch ein älterer lokaler Projektordner geöffnet.

## Neu in 0.2

- echtes 16×16-Tile-Raster, visuell 2× skaliert
- rasterbasierte Vier-Richtungs-Bewegung wie in klassischen Pokémon-/RPG-Maker-Spielen
- Karte aus dem Puny-World-Tileset statt frei gezeichneter Platzhalterwelt
- Gras, Wege, Waldgrenzen, Teich, Vegetation und Gebäude aus dem Tileset
- feste begehbare und blockierte Rasterfelder
- NPC-, Schild- und Tür-Interaktion
- kleiner Pokémon-artiger Dialogbereich
- klassische interne Spielauflösung von 480×320 Pixeln
- weiterhin **kein Kampf und kein ATB**

## Steuerung

- **WASD** oder **Pfeiltasten** – ein Rasterfeld laufen
- **E** oder **Leertaste** – interagieren / Dialog schließen
- **Enter** oder **Escape** – Dialog schließen

## Aktuelles Ziel

Diese Version ist bewusst noch eine Gestaltungsbasis. Als Nächstes werden Map-Komposition, Charakter-Sprites, Tile-Auswahl, Animationen und Details anhand der tatsächlichen Godot-Ansicht weiter verfeinert.

## Assets

Die Tileset-Datei liegt unter `assets/punyworld-overworld-tileset_0.png`. Lizenz- und Quellenhinweise stehen in `ASSET_CREDITS.md`.
