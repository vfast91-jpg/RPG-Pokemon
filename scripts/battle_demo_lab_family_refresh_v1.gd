extends "res://scripts/battle_demo_endgame_v2.gd"

# Final combat-lab family registry refresh.
# Lower family layers append their route roots during _load_data(). The family
# lab itself sits below those layers in the inheritance chain, so its earlier
# snapshot can be stale by the time the UI is built. Refresh once at the very
# top after every family loader has finished.


func _load_data() -> void:
    super._load_data()
    lab_species_ids = species_ids.duplicate()


# Doppelteam's generated mechanics text was technically derived but very hard
# to understand in the infobox. The database contract is simple: enemy attacks
# against the user become less accurate for three of the user's own actions,
# with the strength scaling from the user's Statuswert. Present exactly that to
# the player instead of exposing AP/recovery math or the vague "Treffbarkeit".
func _move_tooltip(move: Dictionary) -> String:
    if str(move.get("id", "")) == "double_team":
        return (
            "👥 Doppelteam · Normal · Status · AP %s\n"
            + "Ziel: Anwender · Dauer: 3 eigene Aktionen\n"
            + "Gegnerische Attacken gegen den Anwender werden ungenauer. "
            + "Stärke abhängig vom Statuswert."
        ) % str(move.get("ap", 6))
    return super._move_tooltip(move)


func _compact_effect_summary(move: Dictionary) -> String:
    if str(move.get("id", "")) == "double_team":
        return "Gegnerische Genauigkeit gegen Anwender ↓ · 3 eigene Aktionen"
    return super._compact_effect_summary(move)
