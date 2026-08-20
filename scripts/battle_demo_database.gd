extends "res://scripts/battle_demo_database_effects.gd"

# Final spreadsheet-database integration layer.
# The two 2026-08-20 workbooks remain the design source; the generated JSON
# snapshot is the runtime source committed with the Godot demo.

const DATABASE_LEVEL_MAX: int = 100


func _load_canonical_database() -> void:
    var manifest: Dictionary = _database_read_json_dictionary(CANONICAL_MANIFEST_PATH)
    if manifest.is_empty():
        push_error("Kanonisches Datenbank-Manifest fehlt oder ist ungültig: " + CANONICAL_MANIFEST_PATH)
        return

    var meta_path: String = str(manifest.get("species_meta_file", ""))
    var meta: Dictionary = _database_read_json_dictionary(meta_path)
    if meta.is_empty():
        push_error("Kanonische Datenbank-Metadaten fehlen: " + meta_path)
        return

    var merged_species: Dictionary = {}
    var species_files_value: Variant = manifest.get("species_files", [])
    if not (species_files_value is Array):
        push_error("Kanonisches Datenbank-Manifest braucht species_files.")
        return
    for path_value: Variant in species_files_value:
        var path: String = str(path_value)
        var pack: Dictionary = _database_read_json_dictionary(path)
        var entries_value: Variant = pack.get("species", {})
        if not (entries_value is Dictionary):
            push_error("Pokémon-Datenpaket ist ungültig: " + path)
            return
        for species_id_value: Variant in (entries_value as Dictionary).keys():
            var species_id: String = str(species_id_value)
            var entry_value: Variant = (entries_value as Dictionary).get(species_id, {})
            if entry_value is Dictionary:
                merged_species[species_id] = (entry_value as Dictionary).duplicate(true)

    var merged_moves: Dictionary = {}
    var move_files_value: Variant = manifest.get("move_files", [])
    if not (move_files_value is Array):
        push_error("Kanonisches Datenbank-Manifest braucht move_files.")
        return
    for path_value: Variant in move_files_value:
        var path: String = str(path_value)
        var pack: Dictionary = _database_read_json_dictionary(path)
        var entries_value: Variant = pack.get("moves", {})
        if not (entries_value is Dictionary):
            push_error("Attacken-Datenpaket ist ungültig: " + path)
            return
        for move_id_value: Variant in (entries_value as Dictionary).keys():
            var move_id: String = str(move_id_value)
            var entry_value: Variant = (entries_value as Dictionary).get(move_id, {})
            if entry_value is Dictionary:
                merged_moves[move_id] = (entry_value as Dictionary).duplicate(true)

    _canonical_pack = meta.duplicate(true)
    _canonical_pack["species"] = merged_species
    _canonical_pack["moves"] = merged_moves
    _canonical_pack["manifest"] = manifest.duplicate(true)

    var runtime_species: Dictionary = {}
    for species_id_value: Variant in merged_species.keys():
        var species_id: String = str(species_id_value)
        var source_value: Variant = merged_species.get(species_id, {})
        if source_value is Dictionary:
            runtime_species[species_id] = _canonical_species_runtime(source_value as Dictionary)

    data["species"] = runtime_species
    data["moves"] = merged_moves.duplicate(true)

    var roots_value: Variant = meta.get("route_roots", [])
    if roots_value is Array:
        species_ids = (roots_value as Array).duplicate()
    else:
        species_ids = []
    data["species_order"] = species_ids.duplicate()

    if runtime_species.size() != int(manifest.get("species_count", runtime_species.size())):
        push_error("Kanonische Datenbank: Pokémon-Anzahl stimmt nicht mit Manifest überein.")
    if merged_moves.size() != int(manifest.get("move_count", merged_moves.size())):
        push_error("Kanonische Datenbank: Attacken-Anzahl stimmt nicht mit Manifest überein.")
    if species_ids.size() != int(manifest.get("route_root_count", species_ids.size())):
        push_error("Kanonische Datenbank: Basislinien-Anzahl stimmt nicht mit Manifest überein.")

    _audit_canonical_database()


func _canonical_learnset_array(learnset_value: Variant) -> Array:
    # RELEARN/Lv.1-Attacken einer neuen Entwicklungsform werden nicht still
    # rückwirkend vergeben. Echte Entwicklungsattacken stehen der Form direkt
    # zur Verfügung; reguläre Level-Attacken folgen ihren Datenbank-Leveln.
    var result: Array = []
    if not (learnset_value is Dictionary):
        return result
    var learnset: Dictionary = learnset_value
    var by_level: Dictionary = {}

    _append_moves_to_level(by_level, 1, learnset.get("evolution_moves", []))

    var level_up_value: Variant = learnset.get("level_up", {})
    if level_up_value is Dictionary:
        for level_key: Variant in (level_up_value as Dictionary).keys():
            var level_text: String = str(level_key)
            if not level_text.is_valid_int():
                continue
            _append_moves_to_level(
                by_level,
                maxi(1, int(level_text)),
                (level_up_value as Dictionary).get(level_key, [])
            )

    var levels: Array[int] = []
    for level_value: Variant in by_level.keys():
        levels.append(int(level_value))
    levels.sort()

    for level: int in levels:
        var usable: Array = []
        var move_values: Variant = by_level.get(level, [])
        if move_values is Array:
            for move_value: Variant in move_values:
                var move_id: String = str(move_value)
                if _database_move_is_runtime_usable(move_id) and not usable.has(move_id):
                    usable.append(move_id)
        if not usable.is_empty():
            result.append({"level": level, "moves": usable})
    return result


func _make_combatant(side: String, index: int, setup: Dictionary) -> Dictionary:
    var enriched: Dictionary = setup.duplicate(true)
    if not (enriched.get("known_moves", null) is Array):
        var species_id: String = str(enriched.get("species_id", ""))
        var level: int = maxi(1, int(enriched.get("level", 1)))
        var root_id: String = _database_family_root(species_id)
        if not root_id.is_empty():
            enriched["known_moves"] = _database_family_moves(root_id, level)
    return super._make_combatant(side, index, enriched)


func route_moves_for_level(species_id: String, level: int) -> Array:
    var root_id: String = _database_family_root(species_id)
    if root_id.is_empty():
        return super.route_moves_for_level(species_id, level)
    return _database_family_moves(root_id, maxi(1, level))


func _database_family_root(species_id: String) -> String:
    if species_id.is_empty():
        return ""
    var species_value: Variant = _canonical_pack.get("species", {})
    if not (species_value is Dictionary):
        return ""
    var all_species: Dictionary = species_value

    for root_value: Variant in species_ids:
        var root_id: String = str(root_value)
        var current_id: String = root_id
        for _hop: int in range(8):
            if current_id == species_id:
                return root_id
            var current_value: Variant = all_species.get(current_id, {})
            if not (current_value is Dictionary):
                break
            var evolution_value: Variant = (current_value as Dictionary).get("evolution", {})
            if not (evolution_value is Dictionary):
                break
            var target_id: String = str((evolution_value as Dictionary).get("evolves_into", ""))
            if target_id.is_empty():
                break
            current_id = target_id
    return ""


func _database_family_moves(root_id: String, level: int) -> Array:
    var result: Array = []
    var species_value: Variant = _canonical_pack.get("species", {})
    if not (species_value is Dictionary):
        return result
    var all_species: Dictionary = species_value
    var current_id: String = root_id
    var form_start_level: int = 1

    for _hop: int in range(8):
        var current_value: Variant = all_species.get(current_id, {})
        if not (current_value is Dictionary):
            break
        var current: Dictionary = current_value
        var learnset_value: Variant = current.get("learnset", {})
        var learnset: Dictionary = learnset_value if learnset_value is Dictionary else {}

        if form_start_level > 1:
            _database_append_usable_moves(result, learnset.get("evolution_moves", []))

        var evolution_value: Variant = current.get("evolution", {})
        var evolution: Dictionary = evolution_value if evolution_value is Dictionary else {}
        var evolution_level: int = int(evolution.get("evolution_level", 0))
        var upper_level: int = level
        if evolution_level > 0:
            upper_level = mini(level, evolution_level - 1)

        var level_up_value: Variant = learnset.get("level_up", {})
        if level_up_value is Dictionary:
            var levels: Array[int] = []
            for level_key: Variant in (level_up_value as Dictionary).keys():
                var level_text: String = str(level_key)
                if level_text.is_valid_int():
                    levels.append(int(level_text))
            levels.sort()
            for move_level: int in levels:
                if move_level < form_start_level or move_level > upper_level:
                    continue
                _database_append_usable_moves(
                    result,
                    (level_up_value as Dictionary).get(str(move_level), [])
                )

        var target_id: String = str(evolution.get("evolves_into", ""))
        if evolution_level <= 0 or target_id.is_empty() or level < evolution_level:
            break
        current_id = target_id
        form_start_level = evolution_level

    return result


func _database_append_usable_moves(result: Array, move_values: Variant) -> void:
    if not (move_values is Array):
        return
    for move_value: Variant in move_values:
        var move_id: String = str(move_value)
        if _database_move_is_runtime_usable(move_id) and not result.has(move_id):
            result.append(move_id)


func _build_config(root: Control) -> void:
    super._build_config(root)
    if config_panel != null and config_panel.get_child_count() > 0:
        var outer: VBoxContainer = config_panel.get_child(0) as VBoxContainer
        if outer != null and outer.get_child_count() > 1:
            var subtitle: Label = outer.get_child(1) as Label
            if subtitle != null:
                subtitle.text = "Pokémon wählen · Level 1–100 · 1–4 pro Seite"


func _fill_rows(box: VBoxContainer, setup: Array, own: bool) -> void:
    super._fill_rows(box, setup, own)
    for row_value: Variant in box.get_children():
        if not (row_value is HBoxContainer):
            continue
        for child_value: Variant in (row_value as HBoxContainer).get_children():
            if child_value is SpinBox:
                var level_picker: SpinBox = child_value
                level_picker.max_value = float(DATABASE_LEVEL_MAX)


func _level_changed(value: float, own: bool, index: int) -> void:
    var setup: Array = player_setup if own else enemy_setup
    if index < 0 or index >= setup.size():
        return
    setup[index]["level"] = clampi(int(value), 1, DATABASE_LEVEL_MAX)


func _randomize_setup() -> void:
    if species_ids.is_empty():
        return

    var player_amount: int = randi_range(1, TEAM_MAX)
    var enemy_amount: int = randi_range(1, TEAM_MAX)
    player_setup.clear()
    enemy_setup.clear()

    for _index: int in range(player_amount):
        player_setup.append({
            "species_id": str(species_ids.pick_random()),
            "level": randi_range(1, DATABASE_LEVEL_MAX)
        })
    for _index: int in range(enemy_amount):
        enemy_setup.append({
            "species_id": str(species_ids.pick_random()),
            "level": randi_range(1, DATABASE_LEVEL_MAX)
        })

    player_count.set_value_no_signal(float(player_amount))
    enemy_count.set_value_no_signal(float(enemy_amount))
    _refresh_setup()


func _prompt_player(actor: Dictionary) -> void:
    if _database_run_forced_action(actor):
        return

    var original_moves: Variant = actor.get("moves", [])
    actor["moves"] = _database_normal_battle_moves(original_moves)
    super._prompt_player(actor)
    actor["moves"] = original_moves


func _enemy_act(actor: Dictionary) -> void:
    if _database_run_forced_action(actor):
        return

    var original_moves: Variant = actor.get("moves", [])
    var usable: Array = _database_normal_battle_moves(original_moves)
    actor["moves"] = usable
    if usable.is_empty():
        actor["moves"] = original_moves
        _database_enemy_wait(actor)
        return
    super._enemy_act(actor)
    actor["moves"] = original_moves


func _database_enemy_wait(actor: Dictionary) -> void:
    actor["aggro"] = float(actor.get("aggro", 0.0)) * 0.55
    actor["atb"] = 0.0
    actor["cycle"] = 0.70
    _set_log(_actor_name(actor) + " wartet.")
    _refresh_cards()


func _database_normal_battle_moves(move_values: Variant) -> Array:
    var result: Array = []
    if not (move_values is Array):
        return result
    for move_value: Variant in move_values:
        var move_id: String = str(move_value)
        var move: Dictionary = _move_data(move_id)
        if move.is_empty():
            continue
        var runtime_value: Variant = move.get("runtime", {})
        var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
        if runtime.has("runtime_supported") and not bool(runtime.get("runtime_supported", true)):
            continue
        if runtime.has("normal_battle_available") and not bool(runtime.get("normal_battle_available", true)):
            continue
        result.append(move_id)
    return result


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var move: Dictionary = _move_data(move_id)
    if move.is_empty():
        return

    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var needs_weather_accuracy: bool = runtime.has("weather_accuracy")
    if not needs_weather_accuracy:
        super._execute_move(actor, move_id)
        return

    var original: Dictionary = move.duplicate(true)
    var adjusted: Dictionary = move.duplicate(true)
    var weather_spec_value: Variant = runtime.get("weather_accuracy", {})
    if weather_spec_value is Dictionary:
        var weather_spec: Dictionary = weather_spec_value
        var weather_id: String = str(battle_weather.snapshot().get("weather_id", ""))
        if weather_spec.has(weather_id):
            var accuracy_value: Variant = weather_spec.get(weather_id)
            if str(accuracy_value) == "always_hit":
                adjusted["accuracy"] = null
            else:
                adjusted["accuracy"] = float(accuracy_value)

    data["moves"][move_id] = adjusted
    super._execute_move(actor, move_id)
    data["moves"][move_id] = original


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var runtime_value: Variant = _database_active_move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}

    if bool(runtime.get("powder_move", false)) and _type_array(target.get("types", [])).has("grass"):
        _spawn_feedback_label(target, "🌿 PUDER IMMUN", Color("b9d58d"))
        return 0.0

    var adjusted: Dictionary = mechanic
    if (
        float(runtime.get("sun_special_multiplier", 1.0)) > 1.0
        and str(battle_weather.snapshot().get("weather_id", "")) == "sun"
        and mechanic.has("multiplier_from_special")
    ):
        adjusted = mechanic.duplicate(true)
        adjusted["multiplier_from_special"] = (
            float(mechanic.get("multiplier_from_special", 1.0))
            * float(runtime.get("sun_special_multiplier", 1.0))
        )

    return super._effect(actor, target, adjusted)


func _targets(actor: Dictionary, rule: String) -> Array:
    if rule == "battlefield":
        return [actor]
    return super._targets(actor, rule)
