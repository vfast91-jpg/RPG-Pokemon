extends "res://scripts/battle_demo_special_mechanics.gd"

# Small player-facing polish layer:
# - Damage move previews always show their power directly in the first line.
# - The player-facing name of the internal `special` stat is "Status".
# - Opening/Runde-0 damage moves are audited against the central balance rule.

const OPENING_BALANCE_PATH: String = "res://data/rules/opening_move_balance.json"
const FALLBACK_OPENING_POWER_CAP: int = 20


func _load_data() -> void:
    super._load_data()
    _audit_opening_damage_balance()


func _preview_move(move_id: String, move: Dictionary, touch_confirm: bool = false) -> void:
    super._preview_move(move_id, move, touch_confirm)
    if log_label == null:
        return

    var power_value: Variant = move.get("power", null)
    if power_value == null:
        return

    var marker: String = " · AP "
    if not log_label.text.contains(marker):
        return

    var power: int = int(round(float(power_value)))
    log_label.text = log_label.text.replace(
        marker,
        " · Stärke " + str(power) + marker
    )


func _detail_info(combatant: Dictionary) -> String:
    # Keep the stable internal data key `special`; only the player-facing label changes.
    return super._detail_info(combatant).replace("Spezial ", "Status ")


func _audit_opening_damage_balance() -> void:
    var power_cap: int = _opening_power_cap()
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        return

    var moves: Dictionary = moves_value
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            continue

        var move: Dictionary = move_value
        if not bool(move.get("opening", false)):
            continue
        if str(move.get("category", "status")) == "status":
            continue

        var power_value: Variant = move.get("power", null)
        if power_value == null:
            continue
        var power: int = int(round(float(power_value)))
        if power <= power_cap:
            continue

        push_warning(
            "Runde-0-Balance: " + str(move.get("name", move_id))
            + " hat Stärke " + str(power)
            + ", empfohlenes Maximum ist " + str(power_cap)
            + ". Schnelle Eröffnungsattacken müssen deutlich schwächer sein."
        )


func _opening_power_cap() -> int:
    if not FileAccess.file_exists(OPENING_BALANCE_PATH):
        return FALLBACK_OPENING_POWER_CAP

    var file: FileAccess = FileAccess.open(OPENING_BALANCE_PATH, FileAccess.READ)
    if file == null:
        return FALLBACK_OPENING_POWER_CAP

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return FALLBACK_OPENING_POWER_CAP

    return maxi(1, int(parsed.get("default_power_cap", FALLBACK_OPENING_POWER_CAP)))
