# Landschafts-Hintergründe

Hier liegen die 18 festen Landschaftsbilder für die Routen- und Kampflogik.

Bitte exakt diese Dateinamen als JPG verwenden:

01_meadow_grassland.jpg
02_forest.jpg
03_jungle.jpg
04_desert.jpg
05_canyon_rockland.jpg
06_lakeshore.jpg
07_coast_beach.jpg
08_swamp_moor.jpg
09_mountains.jpg
10_tundra.jpg
11_volcano_lavafield.jpg
12_cave.jpg
13_city.jpg
14_industry_powerplant.jpg
15_ruins.jpg
16_mystic_place.jpg
17_glacier_ice_lake.jpg
18_temple_monastery.jpg

Die stabile technische Zuordnung von Landschafts-ID, Anzeigename, Bildpfad, Typ-Gewichtung und Kampf-Framing liegt in `res://data/landscapes_v1.json`.

## Kampf-Framing

Die Kampfoberfläche ist deutlich breiter als die Landschaftsquellen. Deshalb darf der Renderer die Bilder nicht mehr ausschließlich mit `KEEP_ASPECT_COVERED` auf die komplette Arena ziehen: Das würde große Teile oben und unten abschneiden und die Landschaft optisch stark heranzoomen.

Der BattleDemo nutzt stattdessen ein dauerhaftes Panorama-Framing mit zwei Ebenen:

- eine Cover-Ebene füllt die seitlichen Bereiche hinter den Statuskarten;
- eine scharfe Fokus-Ebene zeigt im eigentlichen Pokémon-Kampfbereich fast das vollständige Landschaftsbild;
- `battle_framing` pro Landschaft steuert `zoom`, `focus_x`, `focus_y`, `offset_x` und `offset_y`.

Der Standard-Zoom ist bewusst nur `1.18`. Änderungen sollten in kleinen Schritten erfolgen; der Regressionstest verhindert Werte über `1.35`, damit die alte extreme Nahansicht nicht versehentlich zurückkehrt.
