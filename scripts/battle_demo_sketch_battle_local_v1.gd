extends "res://scripts/battle_demo_aggro_rules_final_v2.gd"

# Farbeagle / Nachahmer (Sketch): copied moves belong to one battle only.
#
# The older V23 layer intentionally persisted copied moves in the route team
# state. That makes a bad copy survive into later encounters and can eventually
# remove Sketch permanently after four copies. This leaf keeps the established
# in-battle behavior (up to four different copies), but strips that transient
# state whenever a new combatant/wave is built and after route state is stored.
# It also patches the player-facing move text so UI and runtime describe the
# same battle-local rule.

const SKETCH_MOVE_ID: String = "sketch"
const SKETCH_STATE_KEY: String = "v23_sketch_learned_moves"


func _load_data() -> void:
    super._load_data()
    _sketch_patch_move_text(data)
    _sketch_patch_move_text(_canonical_pack)


func route_new_member(species_id: String, level: int) -> Dictionary:
    var member: Dictionary = super.route_new_member(species_id, level)
    # Never seed a newly obtained Pokemon with the legacy persistent-copy key.
    member.erase(SKETCH_STATE_KEY)
    return member


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    # Old route saves can contain both the legacy copy list and those same move
    # ids in the normal move array. Let the inherited stack build normally, then
    # remove exactly the ids that were recorded as Sketch copies.
    var legacy_copies: Array[String] = _v23_string_array(
        setup.get(SKETCH_STATE_KEY, [])
    )
    var combatant: Dictionary = super._make_combatant(side, index, setup)
    _sketch_clear_legacy_copies(combatant, legacy_copies)
    combatant[SKETCH_STATE_KEY] = []
    return combatant


func _route_begin_wave() -> void:
    super._route_begin_wave()
    if not route_mode:
        return

    # The V23 ancestor reloads the legacy key after combatant construction.
    # Undo that reload immediately and repair old exhausted Farbeagle by putting
    # Sketch back once the stale copied moves have been removed.
    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        if team_index < 0 or team_index >= _route_team_state.size():
            continue

        var state_value: Variant = _route_team_state[team_index]
        var combatant_value: Variant = player_team[local_index]
        if not (state_value is Dictionary) or not (combatant_value is Dictionary):
            continue

        var state: Dictionary = state_value
        var combatant: Dictionary = combatant_value
        var legacy_copies: Array[String] = _v23_string_array(
            state.get(SKETCH_STATE_KEY, [])
        )
        _sketch_clear_legacy_copies(combatant, legacy_copies)
        combatant[SKETCH_STATE_KEY] = []
        state.erase(SKETCH_STATE_KEY)
        _route_team_state[team_index] = state


func _route_store_current_state() -> void:
    # Snapshot the battle-local copies before the V23 ancestor writes them into
    # route state. Afterwards we remove only those transient ids again.
    var copies_by_team_index: Dictionary = {}
    for local_index: int in range(player_team.size()):
        if local_index >= _route_active_indices.size():
            break
        var team_index: int = _route_active_indices[local_index]
        if team_index < 0 or team_index >= _route_team_state.size():
            continue
        var combatant_value: Variant = player_team[local_index]
        if not (combatant_value is Dictionary):
            continue
        copies_by_team_index[team_index] = _v23_string_array(
            (combatant_value as Dictionary).get(SKETCH_STATE_KEY, [])
        )

    super._route_store_current_state()

    for team_index_value: Variant in copies_by_team_index.keys():
        var team_index: int = int(team_index_value)
        if team_index < 0 or team_index >= _route_team_state.size():
            continue
        var state_value: Variant = _route_team_state[team_index]
        if not (state_value is Dictionary):
            continue

        var state: Dictionary = state_value
        var battle_copies: Array[String] = _v23_string_array(
            copies_by_team_index.get(team_index, [])
        )
        _sketch_clear_legacy_copies(state, battle_copies)
        state.erase(SKETCH_STATE_KEY)
        _route_team_state[team_index] = state


func _sketch_clear_legacy_copies(holder: Dictionary, copied_ids: Array[String]) -> void:
    if copied_ids.is_empty():
        return

    var moves: Array[String] = _v23_string_array(holder.get("moves", []))
    for move_id: String in copied_ids:
        moves.erase(move_id)

    # A V23 Farbeagle that already reached four persistent copies had Sketch
    # removed. Restoring it here makes old route state usable again.
    if not moves.has(SKETCH_MOVE_ID):
        moves.insert(0, SKETCH_MOVE_ID)
    holder["moves"] = moves


func _sketch_patch_move_text(container: Dictionary) -> void:
    var moves_value: Variant = container.get("moves", {})
    if not (moves_value is Dictionary):
        return
    var moves: Dictionary = moves_value
    var sketch_value: Variant = moves.get(SKETCH_MOVE_ID, {})
    if not (sketch_value is Dictionary):
        return

    var sketch: Dictionary = (sketch_value as Dictionary).duplicate(true)
    sketch["description"] = (
        "Kopiert die zuletzt vom Ziel eingesetzte kopierbare Attacke für den aktuellen Kampf."
    )
    sketch["special_rules"] = [
        "Kopierte Attacken gelten nur im aktuellen Kampf und verschwinden danach wieder.",
        "Pro Kampf können bis zu 4 verschiedene kopierbare Attacken gesammelt werden; nach der vierten erfolgreichen Kopie ist Nachahmer für diesen Kampf verbraucht.",
        "Kopier-/Zufalls-/Meta-Attacken wie Nachahmer, Mimikry, Copycat, Metronom und Schlafrede sind nicht kopierbar."
    ]

    var tags: Array[String] = _v23_string_array(sketch.get("optional_tags", []))
    tags.erase("persistent_copy")
    if not tags.has("battle_local_copy"):
        tags.append("battle_local_copy")
    sketch["optional_tags"] = tags

    var runtime_value: Variant = sketch.get("runtime", {})
    var runtime: Dictionary = (
        (runtime_value as Dictionary).duplicate(true)
        if runtime_value is Dictionary else {}
    )
    runtime["v23_sketch"] = true
    runtime["battle_local_copy"] = true
    sketch["runtime"] = runtime

    moves[SKETCH_MOVE_ID] = sketch
    container["moves"] = moves
