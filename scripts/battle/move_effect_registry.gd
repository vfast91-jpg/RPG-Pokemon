extends RefCounted
class_name MoveEffectRegistry

const IMPLEMENTED: String = "implemented"
const PARTIAL: String = "partial"
const UNSUPPORTED: String = "unsupported"

# One registry entry is the contract between attack data, runtime and every
# player-facing surface. Bad Poison, Freeze and Zurückschrecken are fully
# implemented by the final Timeflow battle layers.
#
# Zurückschrecken deliberately requires only a chance. Historical `amount`
# fields are legacy metadata; the canonical effect is always ATB -> 0 %.
const EFFECTS: Dictionary = {
    "damage": {"player_label":"Schaden","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "status": {"player_label":"Haupt-/Kampfstatus","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["status"]},
    "db_status": {"player_label":"Haupt-/Kampfstatus","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["status"]},
    "outgoing_damage_mod": {"player_label":"Angriff","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["multiplier_from_special"]},
    "incoming_damage_mod": {"player_label":"Verteidigung","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["multiplier_from_special"]},
    "accuracy_mod": {"player_label":"Genauigkeit","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["multiplier_from_special"]},
    "atb_cycle_mod": {"player_label":"Geschwindigkeit","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["multiplier_from_special"]},
    "atb_knockback": {"player_label":"Zurückschrecken","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":["chance"]},
    "critical_focus": {"player_label":"Volltrefferchance","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "seed": {"player_label":"Egelsamen","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "binding": {"player_label":"Fesselung","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["min_ticks","max_ticks"]},
    "cleanse_self": {"player_label":"Reinigung","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "recoil": {"player_label":"Rückstoß","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":["fraction"]},
    "weather": {"player_label":"Wetter","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "db_incoming_accuracy": {"player_label":"Treffbarkeit","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["direction","multiplier_from_special"]},
    "db_heal_self": {"player_label":"KP-Heilung","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_team_cleanse": {"player_label":"Team-Statusheilung","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":["status"]},
    "db_team_immunity": {"player_label":"Team-Statusschutz","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["status","duration_actions"]},
    "db_clear_allied_hazards": {"player_label":"Feldgefahren entfernen","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_next_cycle_mod": {"player_label":"Nächsten ATB-Zyklus verändern","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":["multiplier_from_special"]},
    "db_berry_interaction": {"player_label":"Beereninteraktion","runtime_state":PARTIAL,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_protect": {"player_label":"Schutzschild","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "db_chance_mechanic": {"player_label":"Zufällige Zusatzwirkung","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":["chance","mechanic"]},
    "db_team_modifier": {"player_label":"Team-Attributänderung","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["modifier_kind","multiplier_from_special"]},
    "db_redirect": {"player_label":"Einzelziel-Umlenkung","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["duration_actions"]},
    "db_guaranteed_crit": {"player_label":"Garantierter Volltreffer","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "db_toxic_spikes": {"player_label":"Giftspitzen","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["max_layers"]},
    "db_equalize_hp": {"player_label":"KP angleichen","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_on_ko_modifier": {"player_label":"K.O.-Bonus","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["modifier_kind","multiplier_from_special"]},
    "db_remove_type_until_next_action": {"player_label":"Typ vorübergehend entfernen","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["type"]},
    "db_fraction_hp_damage": {"player_label":"Prozentualer KP-Schaden","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":["fraction"]},
    "db_stockpile": {"player_label":"Horter-Ladung","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["max"]},
    "db_swallow": {"player_label":"Horter-Heilung","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_spit_up": {"player_label":"Horter-Angriff","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_cleanse_positive_modifiers": {"player_label":"Positive Effekte entfernen","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_block_positive_modifiers": {"player_label":"Positive Effekte blockieren","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["duration_actions"]},
    "db_block_move_category": {"player_label":"Attackenart-Sperre","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["category","duration_actions"]},
    "db_clear_all_temporary_modifiers": {"player_label":"Temporäre Attributänderungen entfernen","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_break_protect": {"player_label":"Schutzschild durchbrechen","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "db_light_screen": {"player_label":"Lichtschild","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":["duration_actions"]},
    "db_atb_pause": {"player_label":"ATB-Pause","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "bulba_endure": {"player_label":"Ausdauer","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "bulba_rest": {"player_label":"Erholung","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "bulba_sleep_talk": {"player_label":"Schlafrede","runtime_state":IMPLEMENTED,"persistent":false,"tooltip":true,"detail":true,"status_card":false,"required_fields":[]},
    "bulba_substitute": {"player_label":"Delegator","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "bulba_helping_hand": {"player_label":"Rechte Hand","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]},
    "bulba_grassy_terrain": {"player_label":"Grasfeld","runtime_state":IMPLEMENTED,"persistent":true,"tooltip":true,"detail":true,"status_card":true,"required_fields":[]}
}

const STATUSES: Dictionary = {
    "paralysis": {"player_label":"Paralyse","runtime_state":IMPLEMENTED},
    "burn": {"player_label":"Verbrennung","runtime_state":IMPLEMENTED},
    "poison": {"player_label":"Vergiftung","runtime_state":IMPLEMENTED},
    "bad_poison": {"player_label":"Schwere Vergiftung","runtime_state":IMPLEMENTED},
    "confusion": {"player_label":"Verwirrung","runtime_state":IMPLEMENTED},
    "sleep": {"player_label":"Schlaf","runtime_state":IMPLEMENTED},
    "freeze": {"player_label":"Gefroren","runtime_state":IMPLEMENTED},
    "major_status": {"player_label":"Hauptstatus","runtime_state":IMPLEMENTED}
}

const TARGETS: Array[String] = ["enemy_highest_aggro", "all_enemies", "self", "all_allies", "all_other_active_pokemon", "enemy_field", "global_battlefield", "battlefield", "single_ally"]
const CATEGORIES: Array[String] = ["physical", "special", "status"]
const TYPES: Array[String] = ["normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison", "ground", "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy"]

static func effect_spec(kind: String) -> Dictionary:
    var value: Variant = EFFECTS.get(kind, {})
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}

static func status_spec(status_id: String) -> Dictionary:
    var value: Variant = STATUSES.get(status_id, {})
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}

static func is_known_effect(kind: String) -> bool:
    return EFFECTS.has(kind)

static func is_known_status(status_id: String) -> bool:
    return STATUSES.has(status_id)

static func is_known_target(target: String) -> bool:
    return TARGETS.has(target)

static func is_known_type(type_id: String) -> bool:
    return TYPES.has(type_id)

static func is_known_category(category: String) -> bool:
    return CATEGORIES.has(category)

static func player_label_for_effect(kind: String) -> String:
    return str(effect_spec(kind).get("player_label", ""))

static func player_label_for_status(status_id: String) -> String:
    return str(status_spec(status_id).get("player_label", status_id))

static func surface_contract_errors() -> Array[String]:
    var errors: Array[String] = []
    for kind_value: Variant in EFFECTS.keys():
        var kind: String = str(kind_value)
        var spec: Dictionary = effect_spec(kind)
        for key: String in ["player_label", "runtime_state", "tooltip", "detail", "status_card"]:
            if not spec.has(key):
                errors.append(kind + ": Registry-Feld fehlt: " + key)
        if str(spec.get("player_label", "")).strip_edges().is_empty():
            errors.append(kind + ": player_label darf nicht leer sein.")
        if not [IMPLEMENTED, PARTIAL, UNSUPPORTED].has(str(spec.get("runtime_state", ""))):
            errors.append(kind + ": ungültiger runtime_state.")
    return errors
