# Kampfhintergründe – Format und Systematik

Der aktive Kampfbereich ist **632 × 216 px** groß.

## Aktuelle Landschaftsbilder

Die 18 festen Landschaftsbilder liegen gesammelt unter:

`assets/battle_backgrounds/landscapes/`

Sie werden als **JPG** gespeichert. Die verbindlichen Dateinamen stehen dort in `README.md`; die technische Zuordnung von Landschafts-ID, Anzeigename und Bildpfad liegt in `res://data/landscapes_v1.json`.

Die vorhandenen Landschafts-Originale sind bewusst **4:3**. Sie werden nicht verändert oder dauerhaft zugeschnitten. Im breiten Kampfbereich werden sie proportional mit `KEEP_ASPECT_COVERED` dargestellt; dabei darf für die Anzeige an den Rändern Bildinhalt abgeschnitten werden, ohne das Seitenverhältnis zu verzerren.

## Bildaufbau

- Keine Schrift, Rahmen oder HUD-Elemente in das Bild malen.
- Der mittlere Bereich soll als gut lesbare Kampffläche funktionieren.
- Helligkeit und Kontrast so wählen, dass helle und dunkle Pokémon erkennbar bleiben.
- Wichtige Motive möglichst nicht ausschließlich an den äußersten Bildrändern platzieren, weil diese bei der breiten Kampfdarstellung beschnitten werden können.

## Einbindung

Der aktive Battle-Layer besitzt `set_battle_background(path)` und startet mit:

`res://assets/battle_backgrounds/landscapes/01_meadow_grassland.jpg`

Die Route kann dadurch pro Etappe eine Landschaft setzen, ohne die Originalbilder zu verändern oder das Kampfsystem neu aufzubauen.
