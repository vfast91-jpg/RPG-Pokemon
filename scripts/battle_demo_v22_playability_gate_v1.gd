extends "res://scripts/battle_demo_v22_consistency_v1.gd"

# Final playability gate for the V22 attack set.
# This layer intentionally sits above every historical family/runtime layer.
# It owns only cross-generation invariants: canonical move completeness,
# canonical target resolution and the one V22 hybrid target picker that older
# layers never had to support.

const V22MoveCatalog = preload("res://scripts/battle/v22_move_catalog.gd")

const V22_HYBRID_TARGET_MOVE_IDS: Array[String] = ["swagger", "flatter"]
const V22_RUNTIME_ONLY_METADATA_KEYS: Array[String] = [
    "runtime_supported", "strict_contract", "contract_validated",
    "contract_errors", "partial", "notes", "normal_battle_available"
]

var _v22_hybrid_picker_move_id: String = ""


func _v22_apply_runtime_fixes() -> void:
    super._v22_apply_runtime_fixes()

    # Canonical V22 targeting contracts that are neither simple highest-aggro
    # enemy nor the already-supported single ally/self-or-ally cases.
    for move_id: String in V22_HYBRID_TARGET_MOVE_IDS:
        _v22_set_target(move_id, "enemy_highest_aggro_or_single_ally", false)

    _v22_set_target("dragon_cheer", "all_allies_except_self", true)


func _choose_move(move_id: String) -> void:
    if selected_actor.is_empty():
        return

    if (
        V22_HYBRID_TARGET_MOVE_IDS.has(move_id)
        and _v22_hybrid_picker_move_id.is_empty()
    ):
        _v22_show_enemy_or_ally_picker(selected_actor, move_id)
        return

    super._choose_move(move_id)


func _v22_show_enemy_or_ally_picker(actor: Dictionary, move_id: String) -> void:
    paused = true
    selected_actor = actor
    _v22_hybrid_picker_move_id = move_id
    _clear_actions()

    var highest_enemy: Dictionary = _highest_aggro(actor)
    var ally_candidates: Array = []
    for candidate_value: Variant in _team_for_side(str(actor.get("side", ""))):
        if not (candidate_value is Dictionary):
            continue
        var candidate: Dictionary = candidate_value
        if not bool(candidate.get("alive", false)):
            continue
        if str(candidate.get("id", "")) == str(actor.get("id", "")):
            continue
        ally_candidates.append(candidate)

    if highest_enemy.is_empty() and ally_candidates.is_empty():
        _v22_hybrid_picker_move_id = ""
        _set_log("Für " + str(_move_data(move_id).get("name", move_id)) + " gibt es kein gültiges Ziel.")
        _prompt_player(actor)
        return

    _set_log(
        "[b]%s[/b]: Ziel für %s wählen."
        % [_actor_name(actor), str(_move_data(move_id).get("name", move_id))]
    )

    if not highest_enemy.is_empty():
        var enemy_button := Button.new()
        enemy_button.text = "Gegner · " + _actor_name(highest_enemy) + " (höchste Aggro)"
        enemy_button.custom_minimum_size = Vector2(220, 29)
        enemy_button.pressed.connect(_v22_confirm_hybrid_enemy.bind(actor, move_id))
        action_grid.add_child(enemy_button)

    for ally_value: Variant in ally_candidates:
        var ally: Dictionary = ally_value
        var ally_button := Button.new()
        ally_button.text = "Verbündeter · " + _actor_name(ally)
        ally_button.custom_minimum_size = Vector2(220, 29)
        ally_button.pressed.connect(
            _v22_confirm_hybrid_ally.bind(
                actor, move_id, str(ally.get("id", ""))
            )
        )
        action_grid.add_child(ally_button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK"
    back_button.custom_minimum_size = Vector2(220, 29)
    back_button.pressed.connect(_v22_cancel_hybrid_picker.bind(actor))
    action_grid.add_child(back_button)


func _v22_confirm_hybrid_enemy(actor: Dictionary, move_id: String) -> void:
    if actor.is_empty():
        return
    _zf_selected_target_id = ""
    _v22_hybrid_picker_move_id = "__resolving__"
    selected_actor = actor
    super._choose_move(move_id)
    _v22_hybrid_picker_move_id = ""


func _v22_confirm_hybrid_ally(actor: Dictionary, move_id: String, target_id: String) -> void:
    if actor.is_empty():
        return
    _zf_selected_target_id = target_id
    _v22_hybrid_picker_move_id = "__resolving__"
    selected_actor = actor
    super._choose_move(move_id)
    _v22_hybrid_picker_move_id = ""


func _v22_cancel_hybrid_picker(actor: Dictionary) -> void:
    _zf_selected_target_id = ""
    _v22_hybrid_picker_move_id = ""
    _prompt_player(actor)


func _targets(actor: Dictionary, rule: String) -> Array:
    match rule:
        "enemy_field", "global_battlefield", "battlefield":
            # Field mechanics resolve exactly once. Their mechanic handler owns
            # which side/global state is affected; they do not need a combatant
            # target merely to execute.
            return [actor]
        _:
            return super._targets(actor, rule)


func _target_name(rule: String) -> String:
    match rule:
        "single_enemy":
            return "gewählter Gegner"
        "all_others", "all_other_active_pokemon":
            return "alle anderen aktiven Pokémon"
        "all_combatants":
            return "alle aktiven Pokémon"
        "all_allies_except_self":
            return "alle Verbündeten außer Anwender"
        "enemy_highest_aggro_or_single_ally":
            return "Gegner mit höchster Aggro oder gewählter Verbündeter"
        "enemy_field":
            return "gegnerische Feldseite"
        "global_battlefield", "battlefield":
            return "Kampffeld"
        _:
            return super._target_name(rule)


func _v22_audit_final_move_set() -> void:
    var moves_value: Variant = data.get("moves", {})
    if not (moves_value is Dictionary):
        push_error("V22-Audit: finaler Attackenbestand fehlt.")
        return

    var moves: Dictionary = moves_value
    if V22MoveCatalog.count() != V22_EXPECTED_MOVE_COUNT:
        push_error(
            "V22-Audit: kanonischer Katalog enthält %d statt %d IDs."
            % [V22MoveCatalog.count(), V22_EXPECTED_MOVE_COUNT]
        )

    for move_id: String in V22MoveCatalog.IDS:
        if not moves.has(move_id):
            push_error("V22-Audit: kanonische Attacke fehlt im finalen Runtime-Bestand: " + move_id)
            continue

        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            push_error("V22-Audit: " + move_id + " ist keine gültige Attackendefinition.")
            continue
        var move: Dictionary = move_value

        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        if not bool(runtime.get("runtime_supported", true)):
            push_error("V22-Audit: " + move_id + " ist als runtime_supported=false markiert.")

        if not _v22_move_has_executable_path(move):
            push_error(
                "V22-Audit: " + move_id
                + " besitzt weder ausführbare mechanics noch einen Runtime-Spezialpfad."
            )

    # Extras are allowed as compatibility aliases, but every canonical ID above
    # is mandatory. This prevents a stale count from hiding a missing V22 move.
    if moves.size() < V22MoveCatalog.count():
        push_error(
            "V22-Audit: finaler Runtime-Bestand enthält nur %d Einträge für %d kanonische Attacken."
            % [moves.size(), V22MoveCatalog.count()]
        )


func _v22_move_has_executable_path(move: Dictionary) -> bool:
    var mechanics_value: Variant = move.get("mechanics", [])
    if mechanics_value is Array and not (mechanics_value as Array).is_empty():
        return true

    # A small number of older attacks intentionally execute entirely through
    # runtime flags in an inherited _execute_move hook (Dragon Cheer is one).
    # Metadata-only runtime dictionaries do NOT count as an execution path.
    var runtime_value: Variant = move.get("runtime", {})
    if not (runtime_value is Dictionary):
        return false
    var runtime: Dictionary = runtime_value
    for key_value: Variant in runtime.keys():
        var key: String = str(key_value)
        if V22_RUNTIME_ONLY_METADATA_KEYS.has(key):
            continue
        return true
    return false
