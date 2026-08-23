extends "res://scripts/battle_demo_ad_final_v1.gd"

# Families 21 -> 30 attack block (V20).
# The spreadsheet is the design source; this top layer only adds the runtime
# definitions and the mechanics that are not already covered by central systems.

const F30_MOVE_PACK_PATHS: Array[String] = [
    "res://data/gen1_moves_runtime_v3_27_1_families_21_30.json",
    "res://data/gen1_moves_runtime_v3_27_2_families_21_30.json",
    "res://data/gen1_moves_runtime_v3_27_3_families_21_30.json",
    "res://data/gen1_moves_runtime_v3_27_4_families_21_30.json",
    "res://data/gen1_moves_runtime_v3_27_5_families_21_30.json"
]
const F30_SingleTargetAggroRules = preload("res://scripts/battle/single_target_aggro_rules.gd")
const F30_HAIL_PULSE_SECONDS: float = 10.0
const F30_HAIL_DAMAGE_FRACTION: float = 1.0 / 16.0
const F30_STATUS_CONTROL_HP_FRACTION: float = 0.10

var _f30_active_move_id: String = ""
var _f30_memento_any_effect: bool = false
var _f30_destiny_activation_succeeded: bool = false
var _f30_wide_guard_by_side: Dictionary = {}
var _f30_wide_guard_consumed_sides: Dictionary = {}
var _f30_hail_pulse_remaining: float = F30_HAIL_PULSE_SECONDS

func _load_data() -> void:
    super._load_data()
    _f30_load_move_pack()
    _zf_rebuild_species_runtime_after_move_load()

func _f30_load_move_pack() -> void:
    var runtime_value: Variant = data.get("moves", {})
    var runtime_moves: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var canonical_value: Variant = _canonical_pack.get("moves", {})
    var canonical_moves: Dictionary = canonical_value if canonical_value is Dictionary else {}

    for pack_path: String in F30_MOVE_PACK_PATHS:
        var text: String = FileAccess.get_file_as_string(pack_path)
        var parsed: Variant = JSON.parse_string(text)
        if not (parsed is Dictionary):
            push_error("Familien-21-30-Attackenpaket konnte nicht gelesen werden: " + pack_path)
            continue

        var entries_value: Variant = (parsed as Dictionary).get("moves", {})
        if not (entries_value is Dictionary):
            push_error("Familien-21-30-Attackenpaket besitzt kein moves-Dictionary: " + pack_path)
            continue

        for move_id_value: Variant in (entries_value as Dictionary).keys():
            var move_id: String = str(move_id_value)
            var move_value: Variant = (entries_value as Dictionary).get(move_id_value, {})
            if not (move_value is Dictionary):
                continue
            runtime_moves[move_id] = (move_value as Dictionary).duplicate(true)
            canonical_moves[move_id] = (move_value as Dictionary).duplicate(true)

    data["moves"] = runtime_moves
    _canonical_pack["moves"] = canonical_moves

func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    combatant["f30_aqua_ring_active"] = false
    combatant["f30_aqua_ring_last_heal_serial"] = -1
    combatant["f30_minimize_expires_serial"] = -1
    combatant["f30_mean_look_source_id"] = ""
    combatant["f30_mean_look_aggro_floor"] = 0.0
    combatant["f30_destiny_bond_active"] = false
    combatant["f30_destiny_recast_block"] = false
    combatant["f30_counter_damage"] = 0
    combatant["f30_counter_source_id"] = ""
    combatant["f30_counter_source_serial"] = -1
    combatant["f30_counter_source_move_id"] = ""
    combatant["f30_triple_axel_hit_index"] = 0
    combatant["f30_triple_axel_failed"] = false
    return combatant

func _start_battle() -> void:
    _f30_wide_guard_by_side.clear()
    _f30_wide_guard_consumed_sides.clear()
    _f30_hail_pulse_remaining = F30_HAIL_PULSE_SECONDS
    super._start_battle()

func open_config() -> void:
    _f30_wide_guard_by_side.clear()
    _f30_wide_guard_consumed_sides.clear()
    _f30_hail_pulse_remaining = F30_HAIL_PULSE_SECONDS
    super.open_config()

func _f30_current_move_id() -> String:
    if not _f30_active_move_id.is_empty():
        return _f30_active_move_id
    return _cf_current_move_id()

func _f30_first_target(actor: Dictionary, move: Dictionary) -> Dictionary:
    var targets: Array = _targets(actor, str(move.get("target", "enemy_highest_aggro")))
    if not targets.is_empty() and targets[0] is Dictionary:
        return targets[0] as Dictionary
    return {}
