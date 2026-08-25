extends "res://scripts/demo_route_levelup_evolution_order_fix.gd"

# Controlled top-level layer for the approved 2026-08-22 route rebalance.
# Keeping the redesign here lets us add the new rules without rewriting the
# mature battle, level-up, evolution, team-card and capture-preview layers.

const NORMAL_STAGE_XP_FRACTION: float = 0.50
const ENCOUNTER_FAMILY_DATA_PATH: String = "res://data/gen1_species_encounter_families_v1.json"
# Reisegefährten-Suche: Jede weitere Suche erhöht wie bisher die relative Chance
# auf seltene Familien, kostet dafür aber bewusst Fundlevel. Die Abstände sind
# direkt vom höchsten eigenen Pokémon aus definiert, damit sie über den gesamten
# Run verständlich und konstant bleiben: Suche 1 -1, Suche 2 -3, Suche 3 -5.
const CAPTURE_SEARCH_LEVEL_OFFSETS: Array[int] = [1, 3, 5]
const CAPTURE_SEARCH_RARITY_EXPONENTS: Array[float] = [1.0, 0.5, 0.25]
const CAPTURE_SEARCH_MAX: int = 3
const ROUTE_RARITY_MAX_STAGE: int = 100
const ROUTE_RARITY_STAGE_SHIFT_MAX: float = 2.0

var _encounter_families: Dictionary = {}
var _encounter_species_to_family: Dictionary = {}
var _capture_search_number: int = 0
var _capture_seen_families: Array[String] = []


func start_route() -> void:
    _reset_capture_search_state()
    super.start_route()


func _special_event_choice(kind: String, current_stage: int) -> Dictionary:
    var choice: Dictionary = super._special_event_choice(kind, current_stage)
    if kind == EVENT_CATCH:
        choice["label"] = "🌿 Reisegefährten-Suche"
        choice["hint"] = (
            "Suche bis zu dreimal nach einem möglichen Reisegefährten. Jede weitere Suche erhöht "
            + "die Seltenheitschance, senkt aber das Level des nächsten Funds."
        )
    return choice


func _route_stage_xp(current_stage: int) -> int:
    var previous_stage_xp: int = super._route_stage_xp(current_stage)
    return maxi(
        1,
        int(round(float(previous_stage_xp) * NORMAL_STAGE_XP_FRACTION))
    )


func _capture_level_for_stage(_current_stage: int) -> int:
    # Das Basis-Fundlevel entspricht Suche 1: genau ein Level unter dem aktuell
    # höchsten eigenen Pokémon. Die Etappe selbst verändert dieses Level nicht.
    return maxi(1, _highest_team_level() - CAPTURE_SEARCH_LEVEL_OFFSETS[0])


func _capture_level_for_search(search_number: int) -> int:
    var index: int = clampi(search_number - 1, 0, CAPTURE_SEARCH_LEVEL_OFFSETS.size() - 1)
    return maxi(1, _highest_team_level() - CAPTURE_SEARCH_LEVEL_OFFSETS[index])


func _capture_rarity_exponent_for_search(search_number: int) -> float:
    var index: int = clampi(search_number - 1, 0, CAPTURE_SEARCH_RARITY_EXPONENTS.size() - 1)
    return CAPTURE_SEARCH_RARITY_EXPONENTS[index]


func _route_rarity_progress_for_stage(current_stage: int) -> float:
    var normalized: float = clampf(
        float(current_stage - 1) / float(ROUTE_RARITY_MAX_STAGE - 1),
        0.0,
        1.0
    )
    # Smoothstep: slow change near stage 1 and stage 100, stronger change in
    # the middle. This is the approved soft route-rarity curve.
    return normalized * normalized * (3.0 - 2.0 * normalized)


func _route_rarity_stage_shift(current_stage: int) -> float:
    return ROUTE_RARITY_STAGE_SHIFT_MAX * _route_rarity_progress_for_stage(current_stage)


func _route_rarity_exponent_for_stage(current_stage: int) -> float:
    return 1.0 - _route_rarity_stage_shift(current_stage)


func _capture_effective_rarity_exponent(search_number: int, current_stage: int) -> float:
    return (
        _capture_rarity_exponent_for_search(search_number)
        - _route_rarity_stage_shift(current_stage)
    )


func _reset_capture_search_state() -> void:
    _capture_search_number = 0
    _capture_seen_families.clear()


func _ensure_encounter_family_data() -> void:
    if not _encounter_families.is_empty() and not _encounter_species_to_family.is_empty():
        return

    var file := FileAccess.open(ENCOUNTER_FAMILY_DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Reisegefährten-Suche: Familien-Begegnungsraten fehlen: " + ENCOUNTER_FAMILY_DATA_PATH)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Reisegefährten-Suche: Familien-Begegnungsraten sind ungültig.")
        return

    var families_value: Variant = (parsed as Dictionary).get("families", {})
    var mapping_value: Variant = (parsed as Dictionary).get("species_to_family", {})
    if families_value is Dictionary:
        _encounter_families = (families_value as Dictionary).duplicate(true)
    if mapping_value is Dictionary:
        _encounter_species_to_family = (mapping_value as Dictionary).duplicate(true)


func _family_id_for_species(species_id: String) -> String:
    _ensure_encounter_family_data()
    return str(_encounter_species_to_family.get(species_id, species_id))


func _family_catch_rate(family_id: String) -> float:
    _ensure_encounter_family_data()
    var family_value: Variant = _encounter_families.get(family_id, {})
    if family_value is Dictionary:
        return maxf(0.0001, float((family_value as Dictionary).get("family_catch_rate", 1.0)))
    return 1.0


func _capture_family_weight(family_id: String, search_number: int) -> float:
    return pow(
        _family_catch_rate(family_id),
        _capture_effective_rarity_exponent(search_number, stage)
    )


func _weighted_capture_root(roots: Array, search_number: int) -> String:
    if roots.is_empty():
        return ""

    var candidates: Array[String] = []
    for root_value: Variant in roots:
        var root_id: String = str(root_value)
        var family_id: String = _family_id_for_species(root_id)
        if not _capture_seen_families.has(family_id):
            candidates.append(root_id)

    # Defensive fallback for a future tiny encounter pool: never make the
    # Reisegefährten-Suche unusable merely because every available family was seen once.
    if candidates.is_empty():
        for root_value: Variant in roots:
            candidates.append(str(root_value))

    var total_weight: float = 0.0
    var weights: Array[float] = []
    for root_id: String in candidates:
        var family_id: String = _family_id_for_species(root_id)
        var weight: float = maxf(0.0001, _capture_family_weight(family_id, search_number))
        weights.append(weight)
        total_weight += weight

    if total_weight <= 0.0:
        return candidates.pick_random()

    var roll: float = randf() * total_weight
    var cumulative: float = 0.0
    for index: int in range(candidates.size()):
        cumulative += weights[index]
        if roll <= cumulative:
            return candidates[index]
    return candidates[candidates.size() - 1]


func _begin_capture_event() -> void:
    _reset_capture_search_state()
    _capture_search_number = 1
    _offer_capture_search()


func _resolve_capture_species_for_root(root_id: String, capture_level: int) -> String:
    if battle_demo == null:
        return ""
    if battle_demo.has_method("route_resolve_generated_species_for_level"):
        return str(
            battle_demo.call(
                "route_resolve_generated_species_for_level",
                root_id,
                capture_level
            )
        )
    return str(battle_demo.call("route_resolve_species_for_level", root_id, capture_level))


func _offer_capture_search() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    pending_capture = {}
    _capture_preview_member = {}
    _capture_preview_team_index = -1

    if battle_demo == null:
        return

    var capture_level: int = _capture_level_for_search(_capture_search_number)
    var max_reachable_level: int = _max_reachable_level_from_stage(capture_level, stage)
    var roots: Array = battle_demo.route_species_ids_valid_through_level(max_reachable_level)
    if roots.is_empty():
        event_label.text = "Bei dieser Reisegefährten-Suche zeigt sich heute kein vollständig spielbares Pokémon."
        continue_button.visible = true
        return

    var root_id: String = _weighted_capture_root(roots, _capture_search_number)
    if root_id.is_empty():
        event_label.text = "Für diese Reisegefährten-Suche konnte keine passende Pokémon-Familie bestimmt werden."
        continue_button.visible = true
        return

    var family_id: String = _family_id_for_species(root_id)
    if not _capture_seen_families.has(family_id):
        _capture_seen_families.append(family_id)

    var species_id: String = _resolve_capture_species_for_root(root_id, capture_level)
    if species_id.is_empty():
        event_label.text = "Diese Begegnung wurde verworfen, weil keine gültige System-Entwicklungsform bestimmt werden konnte."
        continue_button.visible = true
        return

    pending_capture = battle_demo.route_new_member(species_id, capture_level)
    if pending_capture.is_empty():
        event_label.text = "Das gefundene Pokémon konnte nicht aus den Speziesdaten erzeugt werden."
        continue_button.visible = true
        return

    pending_capture.erase("prevent_evolution")
    _capture_preview_member = pending_capture.duplicate(true)
    _capture_preview_team_index = -1
    _show_current_capture_offer()


func _show_current_capture_offer() -> void:
    if pending_capture.is_empty():
        return

    _clear_container(capture_actions)
    continue_button.visible = false

    var name: String = str(pending_capture.get("name", "Pokémon"))
    var level: int = maxi(1, int(pending_capture.get("level", 1)))
    event_label.text = (
        "[b]🌿 Reisegefährten · Suche %d/%d[/b]\n"
        + "%s Lv.%d ist dir begegnet. Du kannst es vollständig ansehen und entscheiden, ob es dich begleiten soll."
    ) % [_capture_search_number, CAPTURE_SEARCH_MAX, name, level]

    if team.size() < ROUTE_TEAM_MAX:
        var accept_button := Button.new()
        accept_button.text = "ALS REISEGEFÄHRTEN AUFNEHMEN"
        accept_button.custom_minimum_size = Vector2(0, 28)
        accept_button.pressed.connect(_accept_pending_capture)
        capture_actions.add_child(accept_button)
    else:
        var replace_button := Button.new()
        replace_button.text = "TEAM-POKÉMON ERSETZEN"
        replace_button.custom_minimum_size = Vector2(0, 28)
        replace_button.pressed.connect(_show_replace_choices)
        capture_actions.add_child(replace_button)

    if _capture_search_number < CAPTURE_SEARCH_MAX:
        var next_search: int = _capture_search_number + 1
        var next_level: int = _capture_level_for_search(next_search)
        var search_button := Button.new()
        search_button.text = "WEITERSUCHEN · HÖHERE SELTENHEITSCHANCE · NÄCHSTER FUND LV.%d" % next_level
        search_button.custom_minimum_size = Vector2(0, 28)
        search_button.tooltip_text = (
            "Das aktuelle Pokémon schließt sich dir nicht an. Suche %d erhöht relativ die Chance auf "
            + "seltenere Pokémon-Familien, der nächste Fund ist dafür fest auf Lv.%d."
        ) % [next_search, next_level]
        search_button.pressed.connect(_search_capture_again)
        capture_actions.add_child(search_button)
    else:
        var leave_button := Button.new()
        leave_button.text = "NICHT AUFNEHMEN · SUCHE BEENDEN"
        leave_button.custom_minimum_size = Vector2(0, 28)
        leave_button.tooltip_text = "Nach der dritten Suche gibt es keine weitere Suche und keine EP-Trostbelohnung."
        leave_button.pressed.connect(_leave_capture_without_capture)
        capture_actions.add_child(leave_button)

    _add_capture_preview_card()


func _search_capture_again() -> void:
    if _capture_search_number >= CAPTURE_SEARCH_MAX:
        return
    _capture_search_number += 1
    _offer_capture_search()


func _accept_pending_capture() -> void:
    if pending_capture.is_empty() or team.size() >= ROUTE_TEAM_MAX:
        return

    var accepted: Dictionary = pending_capture
    var name: String = str(accepted.get("name", "Pokémon"))
    var level: int = maxi(1, int(accepted.get("level", 1)))
    team.append(accepted)
    pending_capture = {}

    _capture_preview_team_index = team.size() - 1
    _capture_preview_member = (team[_capture_preview_team_index] as Dictionary).duplicate(true)
    _clear_container(capture_actions)
    event_label.text = "[b]✓ %s Lv.%d schließt sich dir als Reisegefährte an.[/b]" % [name, level]
    continue_button.visible = true
    _refresh_team_panel()
    _add_capture_preview_card()


func _leave_capture_without_capture() -> void:
    if pending_capture.is_empty():
        return

    pending_capture = {}
    _capture_preview_member = {}
    _capture_preview_team_index = -1
    _clear_container(capture_actions)
    event_label.text = (
        "[b]Reisegefährten-Suche beendet.[/b]\n"
        + "Keines der drei gefundenen Pokémon schließt sich dir an. Es gibt dafür keine zusätzliche EP-Belohnung."
    )
    continue_button.visible = true
    _refresh_team_panel()


func _begin_capture_event_again() -> void:
    _show_current_capture_offer()


func _show_full_team_capture_actions() -> void:
    _show_current_capture_offer()


func _add_capture_preview_card() -> void:
    super._add_capture_preview_card()
    if pending_capture.is_empty() or capture_actions == null:
        return

    var card: Node = capture_actions.get_node_or_null("CapturePokemonPreview")
    if card == null:
        return
    _mark_capture_preview_as_found(card)


func _mark_capture_preview_as_found(node: Node) -> bool:
    if node is Label and (node as Label).text == "✓ GEFANGEN":
        (node as Label).text = "🌿 GEFUNDEN"
        return true
    for child: Node in node.get_children():
        if _mark_capture_preview_as_found(child):
            return true
    return false
