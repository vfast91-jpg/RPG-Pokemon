# Aktuelle Audio-Auswahl – Pokémon Timeflow

Stand: 2026-08-22

## Aktive Zuordnung

### Hauptmenü

- `45. Pokémon Gym.mp3`

### Route / Etappenmenü

Vorläufige Intensitätskurve für den reinen Kampf-Run:

- Etappe 1–30: `94. Fight Area (Day).mp3`
- Etappe 31–60: `78. Team Galactic HQ.mp3`
- Etappe 61–80: `91. Victory Road.mp3`
- Etappe 81–90: `82. Spear Pillar.mp3`

Diese vier Zuordnungen sind bewusst leicht austauschbar und sollen nach dem ersten Spieltest nach Geschmack bestätigt oder geändert werden.

### Kämpfe

- `15. Battle! (Wild Pokémon).mp3` → normaler Kampf
- `46. Battle! (Gym Leader).mp3` → besonderer/Bosskampf
- `168. Battle! (Champion).mp3` → Kampf auf Etappe 90 / Finalkampf

### Kurze Musik / Ereignisse

- `16. Victory! (Wild Pokémon).mp3` → normaler Sieg
- `47. Victory! (Gym Leader).mp3` → Boss-/Finalsieg
- `50. Level Up!.mp3` → Level-Up-Fenster
- `18. Obtained an Item!.mp3` → Fundstellen-Belohnung
- `63. Congratulations! Your Pokémon Evolved!.mp3` → Entwicklung abgeschlossen
- `201. Obtained a Pokémon! [Unused].mp3` → Pokémon ins Team aufgenommen

### Soundeffekte

- `freesound_community-whoosh-6316.mp3` → ein gemeinsamer kurzer Attacken-Sound bei jeder tatsächlich ausgeführten Attacke
- Keine Typ- oder Attacken-spezifischen Varianten.

## Technische Einbindung

Die Audio-Steuerung liegt zentral in `res://scripts/audio_manager.gd` und ist als `AudioManager`-Autoload registriert.

Aktive dünne Integrationsschichten:

- `res://scripts/main_audio.gd`
- `res://scripts/battle_demo_audio.gd`
- `res://scripts/demo_route_audio.gd`

Damit bleiben die bestehenden Menü-, Kampf- und Routenmechaniken unverändert und Audio kann unabhängig angepasst werden.

## Globale Loop-Regel

Für **alle langen Musikstücke** gilt vorläufig dieselbe Regel:

- Die ersten **3,0 Sekunden** werden übersprungen.
- Die letzten **5,0 Sekunden** werden nicht abgespielt.
- Sobald die Wiedergabe den Punkt `Tracklänge - 5 Sekunden` erreicht, springt sie direkt zurück auf **Sekunde 3,0**.
- Auch beim erstmaligen Start eines langen Tracks beginnt die Wiedergabe bei **Sekunde 3,0**.
- Kurze Stinger und Soundeffekte bleiben davon unberührt.

Die Regel wird zentral in `audio_manager.gd` umgesetzt und kann bei Bedarf später für einzelne Stücke verfeinert werden, falls ein Track beim Hörtest einen abweichenden musikalischen Loop-Punkt benötigt.
