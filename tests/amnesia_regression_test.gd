extends SceneTree

const StatusBattle = preload("res://scripts/battle_demo_status_softcaps.gd")
const PACK_PATH: String = "res://data/gen1_moves_runtime_v3_27_5_families_21_30.json"


func _initialize() -> void:
    var move: Dictionary = _load_amnesia()
    _test_amnesia_contract(move)
    _test_amnesia_defense_buff(move)
    _test_amnesia_duration(move)
    _test_active_loader_contains_amnesia_pack()
    print("Amnesie regression test: PASS")
    quit(0)


func _load_amnesia() -> Dictionary:
    assert(FileAccess.file_exists(PACK_PATH), "Amnesie-Runtimepaket fehlt.")
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACK_PATH))
    assert(parsed is Dictionary, "Amnesie-Runtimepaket ist kein gültiges JSON-Dictionary.")
    var moves_value: Variant = (parsed as Dictionary).get("moves", {})
    assert(moves_value is Dictionary, "Amnesie-Runtimepaket besitzt kein moves-Dictionary.")
    var move_value: Variant = (moves_value as Dictionary).get("amnesia", {})
    assert(move_value is Dictionary, "Amnesie-Definition fehlt im Runtimepaket.")
    return (move_value as Dictionary).duplicate(true)


func _test_amnesia_contract(move: Dictionary) -> void:
    assert(str(move.get("id", "")) == "amnesia")
    assert(str(move.get("name", "")) == "Amnesie")
    assert(str(move.get("type", "")) == "psychic")
    assert(str(move.get("category", "")) == "status")
    assert(str(move.get("target", "")) == "self")
    assert(int(move.get("original_pp", 0)) == 20)
    assert(int(move.get("ap", 0)) == 5)
    assert(not bool(move.get("area", true)))
    assert(not bool(move.get("contact", true)))
    assert(str(move.get("emoji", "")) == "🧠")

    var tests_value: Variant = move.get("required_behavior_tests", [])
    assert(tests_value is Array)
    var required_tests: Array = tests_value as Array
    assert(required_tests.has("amnesia_defense_buff"))
    assert(required_tests.has("amnesia_duration"))

    var runtime_value: Variant = move.get("runtime", {})
    assert(runtime_value is Dictionary)
    assert(bool((runtime_value as Dictionary).get("runtime_supported", false)))
    assert(bool((runtime_value as Dictionary).get("strict_contract", false)))


func _amnesia_mechanic(move: Dictionary) -> Dictionary:
    var mechanics_value: Variant = move.get("mechanics", [])
    assert(mechanics_value is Array and not (mechanics_value as Array).is_empty())
    var mechanic_value: Variant = (mechanics_value as Array)[0]
    assert(mechanic_value is Dictionary)
    return mechanic_value as Dictionary


func _test_amnesia_defense_buff(move: Dictionary) -> void:
    var mechanic: Dictionary = _amnesia_mechanic(move)
    assert(str(mechanic.get("kind", "")) == "incoming_damage_mod")
    assert(is_equal_approx(float(mechanic.get("multiplier_from_special", 0.0)), -2.0))
    assert(str(mechanic.get("scope", "")) == "self")

    var battle = StatusBattle.new()
    var actor: Dictionary = {"special": 75.0, "types": []}
    var defense_multiplier: float = battle._status_modifier_multiplier(
        actor,
        mechanic,
        "incoming_damage_mod",
        false,
        false
    )

    # Status 75 => R = 0.5. Bei 2× Gewicht muss Amnesie damit den
    # Verteidigungsmultiplikator 2.0 liefern, also eingehenden Schaden halbieren.
    assert(is_equal_approx(defense_multiplier, 2.0))

    var attacker: Dictionary = {
        "level": 50,
        "attack": 100.0,
        "special": 100.0,
        "types": []
    }
    var baseline_target: Dictionary = {
        "defense": 100.0,
        "types": [],
        "action_serial": 0,
        "timed_modifiers": []
    }
    var buffed_target: Dictionary = baseline_target.duplicate(true)
    battle._add_timed_modifier(
        buffed_target,
        "incoming_damage_mod",
        defense_multiplier,
        "Amnesie",
        "Test-Pokémon"
    )

    seed(424242)
    var baseline_damage: int = battle._damage(
        attacker.duplicate(true),
        baseline_target,
        100,
        "normal",
        "physical"
    )
    seed(424242)
    var buffed_damage: int = battle._damage(
        attacker.duplicate(true),
        buffed_target,
        100,
        "normal",
        "physical"
    )
    assert(baseline_damage > 0)
    assert(buffed_damage > 0)
    assert(buffed_damage < baseline_damage, "Amnesie muss eingehenden Schaden tatsächlich reduzieren.")
    assert(
        float(buffed_damage) <= float(baseline_damage) * 0.55,
        "Amnesie mit Status 75 und 2× Gewicht muss ungefähr halbieren."
    )
    battle.free()


func _test_amnesia_duration(move: Dictionary) -> void:
    var mechanic: Dictionary = _amnesia_mechanic(move)
    assert(str(mechanic.get("duration", "")) == "3_actions")

    var battle = StatusBattle.new()
    var target: Dictionary = {
        "action_serial": 0,
        "timed_modifiers": []
    }
    battle._add_timed_modifier(
        target,
        "incoming_damage_mod",
        2.0,
        "Amnesie",
        "Test-Pokémon"
    )

    assert((target.get("timed_modifiers", []) as Array).size() == 1)
    target["action_serial"] = 2
    battle._expire_finished_modifiers(target)
    assert(
        (target.get("timed_modifiers", []) as Array).size() == 1,
        "Amnesie muss nach zwei eigenen Aktionen noch aktiv sein."
    )

    target["action_serial"] = 3
    battle._expire_finished_modifiers(target)
    assert(
        (target.get("timed_modifiers", []) as Array).is_empty(),
        "Amnesie muss nach exakt drei eigenen Aktionen enden."
    )
    battle.free()


func _test_active_loader_contains_amnesia_pack() -> void:
    var registry_text: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_families_21_30_registry_v1.gd"
    )
    assert(
        registry_text.contains("gen1_moves_runtime_v3_27_5_families_21_30.json"),
        "Der aktive Familien-21-30-Loader lädt das Amnesie-Paket nicht."
    )

    var active_stack = load("res://scripts/battle_demo_pvp_active_v1.gd")
    assert(active_stack != null, "Der aktive Kampfstack muss ohne Parserfehler ladbar sein.")
