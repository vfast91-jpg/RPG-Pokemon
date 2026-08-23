extends "res://scripts/battle_demo_zf_payday_v1.gd"

# Landschafts-Hintergründe für das aktive Kampffeld.
# Der bestehende Battle-Presentation-Layer besitzt bereits das wiederverwendbare
# Hintergrundsystem. Dieser Layer wählt deshalb nur das neue Landschaftsbild aus,
# statt ein zweites TextureRect-/Setter-System parallel dazu anzulegen.

const DEFAULT_LANDSCAPE_BACKGROUND: String = "res://assets/battle_backgrounds/landscapes/01_meadow_grassland.jpg"


func _build_battle(root: Control) -> void:
    super._build_battle(root)
    set_battle_background(DEFAULT_LANDSCAPE_BACKGROUND)


# Kompatibilitäts-Hooks für die darüberliegenden Abra->Dodri-Runtime-Layer.
# Die spezialisierten Kindklassen überschreiben diese Hooks mit ihrer eigentlichen
# Logik. Die Basissignaturen müssen hier bereits existieren, damit GDScript auch
# Zwischenlayer einzeln parsen kann und keine Vorwärtsreferenz auf Kindmethoden hat.
func _ad_after_counted_action(_actor: Dictionary) -> void:
    pass


func _ad_snow_active() -> bool:
    return battle_weather.is_active() and battle_weather.current_id() == "snow"


func route_species_types(species_id: String) -> Array:
    # Die Route fragt hier bewusst die bereits aufgelöste Spezies ab. So gilt
    # die Landschaft für die tatsächliche Entwicklungsform der Begegnung und
    # nicht pauschal für den Typ der Familien-Basisform.
    var species_value: Variant = data.get("species", {})
    if not (species_value is Dictionary):
        return []
    var entry_value: Variant = (species_value as Dictionary).get(species_id, {})
    if not (entry_value is Dictionary):
        return []
    var types_value: Variant = (entry_value as Dictionary).get("types", [])
    return (types_value as Array).duplicate() if types_value is Array else []
