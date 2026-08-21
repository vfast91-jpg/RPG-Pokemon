extends RefCounted
class_name MoveContract

const Registry = preload("res://scripts/battle/move_effect_registry.gd")

const TEMP_MODIFIER_KINDS: Array[String] = [
    "outgoing_damage_mod",
    "incoming_damage_mod",
    "accuracy_mod",
    "atb_cycle_mod"
]

const STRICT_REQUIRED_FIELDS: Array[String] = [
    "id",
    "name",
    "description",
    "emoji",
    "type",
    "category",
    "power",
    "accuracy",
    "original_pp",
    "ap",
    "target",
    "area",
    "contact",
    "priority",
    "opening",
    "mechanics",
    "status_scaling",
    "aggro",
    "special_rules",
    "required_behavior_tests"
]

const FORBIDDEN_PLAYER_TEXT: Array[String] = [
    "incoming_damage_mod",
    "outgoing_damage_mod",
    "atb_cycle_mod",
    "eingehender schaden ×",
    "verursachter schaden ×",
    "atb-zyklus ×",
    "effect_source",
    "db_",
    "verwundbar",
    "tempo",
    "initiative",
    "spezial "
]


static func compile_move(source: Dictionary, strict: bool = false) -> Dictionary:
    var move: Dictionary = _normalize_move(source)
    var report: Dictionary = validate_move(str(move.get("id", "")), move, strict)
    report["move"] = move
    return report


static func validate_pack(moves: Dictionary, strict: bool = false) -> Dictionary:
    var report: Dictionary = {
        "ok": true,
        "moves_checked": 0,
        "errors": [],
        "warnings": [],
        "move_reports": {}
    }
    for move_id_value: Variant in moves.keys():
        var move_id: String = str(move_id_value)
        var move_value: Variant = moves.get(move_id, {})
        if not (move_value is Dictionary):
            _append(report, "errors", move_id + ": Attackendefinition ist kein Dictionary.")
            continue
        var move_report: Dictionary = validate_move(move_id, move_value as Dictionary, strict)
        var move_reports_value: Variant = report.get("move_reports", {})
        var move_reports: Dictionary = move_reports_value if move_reports_value is Dictionary else {}
        move_reports[move_id] = move_report
        report["move_reports"] = move_reports
        report["moves_checked"] = int(report.get("moves_checked", 0)) + 1
        for error_value: Variant in move_report.get("errors", []):
            _append(report, "errors", str(error_value))
        for warning_value: Variant in move_report.get("warnings", []):
            _append(report, "warnings", str(warning_value))
    report["ok"] = _report_errors_empty(report)
    return report


static func validate_move(move_id: String, source: Dictionary, strict: bool = false) -> Dictionary:
    var move: Dictionary = _normalize_move(source)
    var id_text: String = move_id if not move_id.is_empty() else str(move.get("id", "<ohne-id>"))
    var report: Dictionary = {"ok": true, "errors": [], "warnings": []}

    for key: String in ["id", "name", "type", "category", "target", "mechanics"]:
        if not move.has(key):
            _append(report, "errors", id_text + ": Pflichtfeld fehlt: " + key)

    if strict:
        for key: String in STRICT_REQUIRED_FIELDS:
            if not move.has(key):
                _append(report, "errors", id_text + ": V4-Vertragsfeld fehlt: " + key)

    if str(move.get("id", "")).strip_edges().is_empty():
        _append(report, "errors", id_text + ": id darf nicht leer sein.")
    if str(move.get("name", "")).strip_edges().is_empty():
        _append(report, "errors", id_text + ": name darf nicht leer sein.")
    if str(move.get("emoji", "")).strip_edges().is_empty():
        _append(report, "errors", id_text + ": Emoji fehlt; UI und Attackenanimation benötigen es.")

    var type_id: String = str(move.get("type", ""))
    if not Registry.is_known_type(type_id):
        _append(report, "errors", id_text + ": unbekannter Typ: " + type_id)

    var category: String = str(move.get("category", ""))
    if not Registry.is_known_category(category):
        _append(report, "errors", id_text + ": unbekannte Kategorie: " + category)

    var target: String = str(move.get("target", ""))
    if not Registry.is_known_target(target):
        _append(report, "errors", id_text + ": unbekannte Zielregel: " + target)

    if move.has("accuracy") and move.get("accuracy") != null:
        var accuracy: float = float(move.get("accuracy", -1.0))
        if accuracy < 0.0 or accuracy > 100.0:
            _append(report, "errors", id_text + ": accuracy muss null oder 0–100 sein.")

    if move.has("ap"):
        var ap: int = int(move.get("ap", 0))
        if ap < 1 or ap > 8:
            _append(report, "errors", id_text + ": RPG-AP müssen 1–8 sein.")

    _validate_target_area(id_text, move, report)
    _validate_aggro(id_text, move, report, strict)
    _validate_player_text(id_text, str(move.get("description", "")), report, strict)

    var runtime_value: Variant = move.get("runtime", {})
    var runtime: Dictionary = runtime_value if runtime_value is Dictionary else {}
    var runtime_supported: bool = bool(runtime.get("runtime_supported", true))
    var runtime_partial: bool = bool(runtime.get("partial", false))
    if strict and not runtime_supported:
        _append(report, "errors", id_text + ": runtime_supported=false; Attacke ist nicht implementierungsbereit.")
    if strict and runtime_partial:
        _append(report, "errors", id_text + ": runtime.partial=true; eine V4-Attacke darf nicht als nur teilweise implementiert freigegeben werden.")
    if runtime_partial:
        var notes_value: Variant = runtime.get("notes", [])
        if not (notes_value is Array) or (notes_value as Array).is_empty():
            _append(report, "errors", id_text + ": partial=true benötigt mindestens eine konkrete runtime.notes-Erklärung.")

    var mechanics_value: Variant = move.get("mechanics", [])
    if not (mechanics_value is Array):
        _append(report, "errors", id_text + ": mechanics/effects muss ein Array sein.")
    else:
        var has_special: bool = false
        var mechanic_index: int = 0
        for mechanic_value: Variant in mechanics_value:
            if not (mechanic_value is Dictionary):
                _append(report, "errors", id_text + ": Mechanik #" + str(mechanic_index) + " ist kein Dictionary.")
            else:
                var mechanic: Dictionary = mechanic_value
                if str(mechanic.get("kind", "")) != "damage":
                    has_special = true
                _validate_mechanic(id_text, mechanic, report, strict, runtime_supported, runtime_partial, "Mechanik #" + str(mechanic_index))
            mechanic_index += 1

        if strict and _needs_behavior_tests(move, has_special):
            var tests_value: Variant = move.get("required_behavior_tests", [])
            if not (tests_value is Array) or (tests_value as Array).is_empty():
                _append(report, "errors", id_text + ": Sondermechanik benötigt required_behavior_tests.")

    report["ok"] = _report_errors_empty(report)
    return report


static func _normalize_move(source: Dictionary) -> Dictionary:
    var move: Dictionary = source.duplicate(true)

    if not move.has("ap") and move.has("rpg_ap"):
        move["ap"] = move.get("rpg_ap")
    if not move.has("opening") and move.has("opening_phase"):
        move["opening"] = move.get("opening_phase")
    if not move.has("priority") and move.has("priority_reference"):
        move["priority"] = move.get("priority_reference")
    if not move.has("mechanics") and move.get("effects", null) is Array:
        var normalized: Array = []
        for mechanic_value: Variant in move.get("effects", []):
            normalized.append(_normalize_mechanic(mechanic_value))
        move["mechanics"] = normalized
    elif move.get("mechanics", null) is Array:
        var normalized_existing: Array = []
        for mechanic_value: Variant in move.get("mechanics", []):
            normalized_existing.append(_normalize_mechanic(mechanic_value))
        move["mechanics"] = normalized_existing

    return move


static func _normalize_mechanic(value: Variant) -> Variant:
    if not (value is Dictionary):
        return value
    var mechanic: Dictionary = (value as Dictionary).duplicate(true)
    var kind: String = str(mechanic.get("kind", ""))
    if kind == "apply_status":
        mechanic["kind"] = "status"
    if str(mechanic.get("kind", "")) == "db_chance_mechanic" and mechanic.get("mechanic", null) is Dictionary:
        mechanic["mechanic"] = _normalize_mechanic(mechanic.get("mechanic"))
    return mechanic


static func _validate_mechanic(
    move_id: String,
    mechanic: Dictionary,
    report: Dictionary,
    strict: bool,
    runtime_supported: bool,
    runtime_partial: bool,
    path: String
) -> void:
    var kind: String = str(mechanic.get("kind", ""))
    if kind.is_empty():
        _append(report, "errors", move_id + ": " + path + " besitzt keine kind-ID.")
        return
    if not Registry.is_known_effect(kind):
        _append(report, "errors", move_id + ": unbekannte Mechanik-ID '" + kind + "' in " + path + ".")
        return

    var spec: Dictionary = Registry.effect_spec(kind)
    for field_value: Variant in spec.get("required_fields", []):
        var field: String = str(field_value)
        if not mechanic.has(field):
            _append(report, "errors", move_id + ": " + path + " (" + kind + ") benötigt Feld '" + field + "'.")

    var state: String = str(spec.get("runtime_state", Registry.UNSUPPORTED))
    if state == Registry.UNSUPPORTED and runtime_supported:
        var message: String = move_id + ": " + path + " nutzt '" + kind + "', dessen zentrale Runtime nicht vollständig unterstützt ist."
        if strict or not runtime_partial:
            _append(report, "errors", message)
        else:
            _append(report, "warnings", message)
    elif state == Registry.PARTIAL and runtime_supported:
        var partial_message: String = move_id + ": " + path + " nutzt nur teilweise unterstützte Mechanik '" + kind + "'."
        if strict:
            _append(report, "errors", partial_message)
        elif not runtime_partial:
            _append(report, "warnings", partial_message + " runtime.partial sollte gesetzt sein.")

    if mechanic.has("chance"):
        var chance: float = float(mechanic.get("chance", -1.0))
        if chance < 0.0 or chance > 1.0:
            _append(report, "errors", move_id + ": " + path + " chance muss 0–1 sein.")

    if (
        TEMP_MODIFIER_KINDS.has(kind)
        and strict
        and not mechanic.has("duration")
        and not mechanic.has("duration_actions")
    ):
        _append(report, "errors", move_id + ": " + path + " benötigt eine explizite Dauer; keine versteckte Standarddauer.")

    if kind == "status" or kind == "db_status":
        var status_id: String = str(mechanic.get("status", ""))
        if not Registry.is_known_status(status_id):
            _append(report, "errors", move_id + ": unbekannter Status '" + status_id + "'.")
        else:
            var status_state: String = str(Registry.status_spec(status_id).get("runtime_state", Registry.UNSUPPORTED))
            if status_state != Registry.IMPLEMENTED and runtime_supported:
                var status_message: String = move_id + ": Status '" + status_id + "' ist zentral nur " + status_state + "."
                if strict or (status_state == Registry.UNSUPPORTED and not runtime_partial):
                    _append(report, "errors", status_message)
                else:
                    _append(report, "warnings", status_message)

    if kind == "db_chance_mechanic":
        var nested_value: Variant = mechanic.get("mechanic", null)
        if nested_value is Dictionary:
            _validate_mechanic(
                move_id,
                nested_value as Dictionary,
                report,
                strict,
                runtime_supported,
                runtime_partial,
                path + " → nested"
            )

    if kind == "db_team_modifier" or kind == "db_on_ko_modifier":
        var modifier_kind: String = str(mechanic.get("modifier_kind", ""))
        if not TEMP_MODIFIER_KINDS.has(modifier_kind):
            _append(report, "errors", move_id + ": " + path + " besitzt ungültigen modifier_kind '" + modifier_kind + "'.")


static func _validate_target_area(move_id: String, move: Dictionary, report: Dictionary) -> void:
    var target: String = str(move.get("target", ""))
    var area: bool = bool(move.get("area", false))
    var must_be_area: bool = [
        "all_enemies", "all_allies", "all_other_active_pokemon",
        "enemy_field", "global_battlefield", "battlefield"
    ].has(target)
    if must_be_area and not area:
        _append(report, "errors", move_id + ": Zielregel " + target + " benötigt area=true.")
    if ["self", "enemy_highest_aggro", "single_ally"].has(target) and area:
        _append(report, "errors", move_id + ": Einzelzielregel " + target + " benötigt area=false.")


static func _validate_aggro(move_id: String, move: Dictionary, report: Dictionary, strict: bool) -> void:
    if not strict:
        return
    var aggro_value: Variant = move.get("aggro", null)
    if not (aggro_value is Dictionary):
        _append(report, "errors", move_id + ": aggro muss ein Dictionary sein.")
        return
    var aggro: Dictionary = aggro_value
    for key: String in ["from_damage", "from_status", "from_healing"]:
        if not aggro.has(key):
            _append(report, "errors", move_id + ": aggro." + key + " fehlt.")


static func _validate_player_text(move_id: String, description: String, report: Dictionary, strict: bool) -> void:
    if not strict:
        return
    if description.strip_edges().is_empty():
        _append(report, "errors", move_id + ": description darf im V4-Vertrag nicht leer sein.")
        return
    var lower: String = description.to_lower()
    if description.contains("×"):
        _append(report, "errors", move_id + ": Spielerbeschreibung enthält einen Roh-Multiplikator (×).")
    for token: String in FORBIDDEN_PLAYER_TEXT:
        if lower.contains(token):
            _append(report, "errors", move_id + ": Spielerbeschreibung enthält verbotenen/technischen Begriff: " + token)


static func _needs_behavior_tests(move: Dictionary, has_special_mechanic: bool) -> bool:
    if has_special_mechanic:
        return true

    var runtime_value: Variant = move.get("runtime", {})
    if runtime_value is Dictionary:
        var ignored_runtime_keys: Array[String] = [
            "runtime_supported", "strict_contract", "contract_validated",
            "contract_errors", "notes", "partial", "normal_battle_available",
            "opening_only", "sleep_talk_eligible", "balance_override_reason"
        ]
        for key_value: Variant in (runtime_value as Dictionary).keys():
            if not ignored_runtime_keys.has(str(key_value)):
                return true

    var special_rules_value: Variant = move.get("special_rules", [])
    if special_rules_value is Array:
        return not (special_rules_value as Array).is_empty()
    var special_rules_text: String = str(special_rules_value).strip_edges().to_lower()
    return not special_rules_text.is_empty() and special_rules_text != "none"


static func _report_errors_empty(report: Dictionary) -> bool:
    var errors_value: Variant = report.get("errors", [])
    return not (errors_value is Array) or (errors_value as Array).is_empty()


static func _append(report: Dictionary, key: String, message: String) -> void:
    var values_value: Variant = report.get(key, [])
    var values: Array = values_value if values_value is Array else []
    values.append(message)
    report[key] = values
