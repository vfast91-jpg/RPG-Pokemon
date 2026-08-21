extends SceneTree

const CombatLab = preload("res://scripts/battle_demo_bulbasaur_family_tm_final.gd")


func _initialize() -> void:
    var lab = CombatLab.new()
    root.add_child(lab)

    var actor: Dictionary = lab._make_combatant("player", 0, {"species_id":"bulbasaur","level":5})
    var target: Dictionary = lab._make_combatant("enemy", 0, {"species_id":"bulbasaur","level":5})
    actor["hp"] = actor["max_hp"]
    target["hp"] = target["max_hp"]
    lab.combatants = [actor, target]

    _assert_false_swipe(lab, actor, target)
    _assert_bad_poison(lab, actor, target)
    _assert_knock_off_modifier_choice(lab, target)
    _assert_roar_pause(lab, actor, target)
    _assert_curse(lab, actor, target)
    _assert_weather_ball(lab, actor)
    _assert_state_tags(lab, target)
    _assert_stomping_outcomes(lab)

    print("Bisasam-Familie TM mechanics test: PASS")
    lab.queue_free()
    quit(0)


func _reset_target(target: Dictionary) -> void:
    target["alive"] = true
    target["hp"] = int(target.get("max_hp", 100))
    target["major_status"] = ""
    target["paralyzed"] = false
    target["db_substitute_hp"] = 0
    target["timed_modifiers"] = []
    target["tf_bad_poison_stage"] = 0
    target["tf_bad_poison_source_id"] = ""
    target["tf_curse_effect"] = {}
    target["tf_states"] = {}
    target["tf_atb_pause_remaining"] = 0.0
    target["tf_atb_pause_total"] = 0.0


func _assert_false_swipe(lab, actor: Dictionary, target: Dictionary) -> void:
    _reset_target(target)
    target["hp"] = 10
    lab._tf_active_move_id = "false_swipe"
    var damage: int = lab._damage(actor, target, 1000, "normal", "physical")
    lab._tf_active_move_id = ""
    assert(damage <= 9, "Trugschlag darf bei 10 KP höchstens 9 Schaden liefern.")
    target["hp"] = 1
    lab._tf_active_move_id = "false_swipe"
    damage = lab._damage(actor, target, 1000, "normal", "physical")
    lab._tf_active_move_id = ""
    assert(damage == 0, "Trugschlag muss bei 1 KP auf 0 tatsächlichen Schaden begrenzen.")


func _assert_bad_poison(lab, actor: Dictionary, target: Dictionary) -> void:
    _reset_target(target)
    target["types"] = ["normal"]
    target["max_hp"] = 160
    target["hp"] = 160
    var aggro: float = lab._tf_apply_bad_poison(actor, target)
    assert(is_equal_approx(aggro, 20.0), "Toxin muss bei erfolgreicher Anwendung 20 Status-Aggro erzeugen.")
    assert(str(target.get("major_status", "")) == "bad_poison", "Toxin muss schwere Vergiftung setzen.")
    assert(int(target.get("tf_bad_poison_stage", 0)) == 1, "Schwere Vergiftung muss bei Stufe 1 beginnen.")
    var first: int = lab._tf_tick_bad_poison(target)
    var second: int = lab._tf_tick_bad_poison(target)
    assert(first == 10, "Erster Toxin-Tick bei 160 Max-KP muss 10 Schaden verursachen.")
    assert(second == 20, "Zweiter Toxin-Tick bei 160 Max-KP muss 20 Schaden verursachen.")
    assert(int(target.get("tf_bad_poison_stage", 0)) == 3, "Toxin-Stufe muss nach zwei Ticks auf 3 stehen.")


func _assert_knock_off_modifier_choice(lab, target: Dictionary) -> void:
    _reset_target(target)
    target["timed_modifiers"] = [
        {"kind":"outgoing_damage_mod","multiplier":1.20,"source_move":"Alt","expires_after_action":99},
        {"kind":"incoming_damage_mod","multiplier":1.50,"source_move":"Stark","expires_after_action":99},
        {"kind":"accuracy_mod","multiplier":0.80,"source_move":"Negativ","expires_after_action":99}
    ]
    assert(lab._tf_best_positive_modifier_index(target) == 1, "Abschlag muss den stärksten positiven temporären Effekt wählen.")
    target["timed_modifiers"] = [
        {"kind":"outgoing_damage_mod","multiplier":1.40,"source_move":"Älter","expires_after_action":99},
        {"kind":"incoming_damage_mod","multiplier":1.40,"source_move":"Neuer","expires_after_action":99}
    ]
    assert(lab._tf_best_positive_modifier_index(target) == 0, "Bei Gleichstand muss Abschlag den älteren Effekt wählen.")


func _assert_roar_pause(lab, actor: Dictionary, target: Dictionary) -> void:
    _reset_target(target)
    actor["special"] = 75
    target["speed"] = 60
    target["cycle"] = 1.0
    var full_cycle: float = lab._tf_full_atb_cycle_seconds(target)
    var effect_aggro: float = lab._tf_apply_atb_pause(actor, target)
    var pause: float = float(target.get("tf_atb_pause_remaining", 0.0))
    assert(is_equal_approx(pause / full_cycle, 0.5), "Brüller mit Statuswert 75 muss einen halben Zielzyklus pausieren.")
    assert(effect_aggro > 0.0, "Brüller muss Aggro aus der tatsächlich erzeugten Pause erhalten.")


func _assert_curse(lab, actor: Dictionary, target: Dictionary) -> void:
    _reset_target(target)
    actor["types"] = ["grass","poison"]
    actor["timed_modifiers"] = []
    assert(lab._tf_apply_non_ghost_curse(actor), "Nicht-Geist-Fluch muss erfolgreich sein.")
    assert((actor.get("timed_modifiers", []) as Array).size() == 3, "Nicht-Geist-Fluch muss drei temporäre Attributseffekte setzen.")

    _reset_target(target)
    actor["types"] = ["ghost"]
    actor["max_hp"] = 100
    actor["hp"] = 100
    actor["alive"] = true
    target["max_hp"] = 100
    target["hp"] = 100
    target["aggro"] = 100.0
    lab.combatants = [actor, target]
    assert(lab._tf_apply_ghost_curse(actor), "Geist-Fluch muss erfolgreich sein.")
    assert(int(actor.get("hp", 0)) == 50, "Geist-Fluch muss 50 % Max-KP kosten.")
    assert(lab._tf_tick_curse(target) == 25, "Geist-Fluch muss nach der Zielaktion 25 % Max-KP verursachen.")
    assert(int(target.get("hp", 0)) == 75, "Fluch-Ziel muss nach einem Tick 75 KP besitzen.")
    var hp_before_reapply: int = int(actor.get("hp", 0))
    assert(not lab._tf_apply_ghost_curse(actor), "Erneuter Geist-Fluch auf dasselbe Ziel muss scheitern.")
    assert(int(actor.get("hp", 0)) == hp_before_reapply, "Fehlgeschlagene Wiederholung darf keine KP kosten.")


func _assert_weather_ball(lab, actor: Dictionary) -> void:
    lab.battle_weather.reset()
    var clear_move: Dictionary = lab._move_data("weather_ball").duplicate(true)
    lab._tf_resolve_weather_ball(clear_move)
    assert(str(clear_move.get("type", "")) == "normal" and int(clear_move.get("power", 0)) == 50, "Meteorologe ohne Wetter muss Normal/Stärke 50 sein.")

    var result: Dictionary = lab.battle_weather.activate("sun", actor)
    assert(bool(result.get("ok", false)), "Sonne muss für den Meteorologe-Test aktivierbar sein.")
    var sun_move: Dictionary = lab._move_data("weather_ball").duplicate(true)
    lab._tf_resolve_weather_ball(sun_move)
    assert(str(sun_move.get("type", "")) == "fire" and int(sun_move.get("power", 0)) == 100, "Meteorologe bei Sonne muss Feuer/Stärke 100 sein.")


func _assert_state_tags(lab, target: Dictionary) -> void:
    lab._tf_set_state(target, "minimized", true)
    assert(lab._tf_has_state(target, "minimized"), "Zentraler Zustand minimized muss abfragbar sein.")
    lab._tf_set_state(target, "underground", true)
    assert(lab._tf_has_state(target, "underground"), "Zentraler Zustand underground muss abfragbar sein.")
    lab._tf_set_state(target, "raised", true)
    assert(not lab._tf_is_grounded(target), "Zentraler Zustand raised muss ein Pokémon vom Boden lösen.")


func _assert_stomping_outcomes(lab) -> void:
    assert(lab.TF_STOMPING_BOOST_OUTCOMES.has("miss"), "Fruststampfer muss nach Verfehlen verstärkt werden.")
    assert(lab.TF_STOMPING_BOOST_OUTCOMES.has("immune"), "Fruststampfer muss nach Immunität verstärkt werden.")
    assert(lab.TF_STOMPING_BOOST_OUTCOMES.has("failed"), "Fruststampfer muss nach Fehlschlag verstärkt werden.")
    assert(not lab.TF_STOMPING_BOOST_OUTCOMES.has("blocked"), "Schutzschild-Block darf Fruststampfer nicht verstärken.")
    assert(not lab.TF_STOMPING_BOOST_OUTCOMES.has("wait"), "Warten darf Fruststampfer nicht verstärken.")
