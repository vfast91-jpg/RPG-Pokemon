extends SceneTree

const StatusEffects = preload("res://scripts/battle/status_effect_runtime.gd")


func _initialize() -> void:
    assert(is_equal_approx(StatusEffects.ratio(25.0), 0.25))
    assert(is_equal_approx(StatusEffects.ratio(75.0), 0.50))
    assert(is_equal_approx(StatusEffects.ratio(300.0), 0.80))

    # Status 75 is the calibration point: old reference strengths remain intact.
    assert(StatusEffects.max_hp_heal(200, 75.0, 1.0) == 100)
    assert(StatusEffects.drain_heal(100, 75.0, 1.0) == 50)
    assert(StatusEffects.drain_heal(100, 75.0, 1.5) == 75)
    assert(
        StatusEffects.drain_heal(1, 1.0, 1.0) == 1,
        "Eine positive Status-Entzugheilung darf nicht auf 0 KP abrunden."
    )
    assert(is_equal_approx(StatusEffects.damage_reduction_multiplier(75.0), 0.50))
    assert(is_equal_approx(StatusEffects.additive_damage_multiplier(75.0, 0.6), 1.30))
    assert(is_equal_approx(StatusEffects.atb_start_percent(75.0, 0.5), 25.0))
    assert(is_equal_approx(StatusEffects.next_cycle_multiplier(75.0, 0.5), sqrt(0.5)))
    assert(is_equal_approx(StatusEffects.critical_bonus_fraction(75.0, 0.5), 0.25))
    assert(is_equal_approx(StatusEffects.critical_bonus_fraction(75.0, 1.0), 0.50))

    # main.tscn is intentionally allowed to gain newer integrity/UI layers over
    # time. Resolve the active BattleDemo script dynamically and verify that the
    # status migration still exists anywhere in its inheritance chain.
    var main_text: String = FileAccess.get_file_as_string("res://main.tscn")
    var battle_resource_regex := RegEx.new()
    assert(
        battle_resource_regex.compile(
            "ext_resource type=\"Script\" path=\"([^\"]+)\" id=\"2_battle\""
        ) == OK
    )
    var match_result: RegExMatch = battle_resource_regex.search(main_text)
    assert(match_result != null, "main.tscn muss eine BattleDemo-Scriptressource besitzen.")
    var active_battle_path: String = match_result.get_string(1)
    var active_script: Script = load(active_battle_path) as Script
    assert(active_script != null, "Die aktive BattleDemo-Runtime muss ladbar sein.")

    var cursor: Script = active_script
    var migration_found: bool = false
    while cursor != null:
        if cursor.resource_path.ends_with("battle_demo_status_effect_migration_v1.gd"):
            migration_found = true
            break
        cursor = cursor.get_base_script()
    assert(
        migration_found,
        "Die aktive BattleDemo-Vererbung muss die Status-Migrationsruntime enthalten."
    )

    var final_runtime: Node = active_script.new() as Node
    assert(final_runtime != null)

    # Focus Energy uses +100R percentage points with no historical +25 PP cap.
    # At Status 75, R=0.5 -> +50 percentage points.
    assert(
        is_equal_approx(float(final_runtime.call("_status_percent", 75.0)), 50.0),
        "Energiefokus muss bei Status 75 +50 Prozentpunkte liefern."
    )

    # Mutual exclusion must work in both orders.
    var dragon_cheer_active: Dictionary = {
        "cf_dragon_cheer_actions": 3,
        "db_focus_energy_bonus_pp": 0.0,
        "critical_focus_bonus": 0.0
    }
    assert(
        bool(final_runtime.call("_v22_focus_energy_blocked_by_dragon_cheer", dragon_cheer_active)),
        "Aktives Drachenjubel muss Energiefokus blockieren."
    )

    var focus_energy_active: Dictionary = {
        "cf_dragon_cheer_actions": 0,
        "db_focus_energy_bonus_pp": 50.0,
        "critical_focus_bonus": 0.5
    }
    assert(
        not bool(final_runtime.call("_cf_dragon_cheer_eligible", focus_energy_active)),
        "Aktiver Energiefokus muss Drachenjubel blockieren."
    )

    # Absorber/Megasauger use the later ZF runtime. One point of actual damage
    # with a small but positive Status share must still restore exactly 1 KP.
    var drain_actor: Dictionary = {
        "id": "drain_actor",
        "hp": 9,
        "max_hp": 10,
        "special": 1.0
    }
    var drain_target: Dictionary = {"id": "drain_target", "hp": 9}
    final_runtime.set("_zf_hp_before", {"drain_target": 10})
    var tiny_drain_heal: float = float(final_runtime.call(
        "_zf_drain",
        drain_actor,
        drain_target,
        {"status_weight": 1.0}
    ))
    assert(
        int(drain_actor.get("hp", 0)) == 10 and is_equal_approx(tiny_drain_heal, 1.0),
        "Absorber und Megasauger müssen bei positiver Heilwirkung mindestens 1 KP heilen."
    )
    final_runtime.free()

    var migration_text: String = FileAccess.get_file_as_string(
        "res://data/rules/status_effect_migration_v1.json"
    )
    var parsed: Variant = JSON.parse_string(migration_text)
    assert(parsed is Dictionary)
    var migration: Dictionary = parsed as Dictionary
    assert(bool(migration.get("runtime_consumed", false)))
    var exceptions_value: Variant = migration.get("explicit_non_migrations", {})
    assert(exceptions_value is Dictionary)
    var exceptions: Dictionary = exceptions_value as Dictionary
    assert(str(exceptions.get("psyshock", "")).contains("damage_stat_override=status"))
    assert(str(exceptions.get("fling", "")).contains("damage_stat_override=status"))

    # Fling's live special-case code must still switch its offensive value to Status.
    var charmander_runtime: String = FileAccess.get_file_as_string(
        "res://scripts/battle_demo_charmander_family_runtime.gd"
    )
    assert(charmander_runtime.contains("var fling_override: bool = move_id == \"fling\""))
    assert(charmander_runtime.contains("actor[\"attack\"] = float(actor.get(\"special\""))

    print("Status effect migration test: PASS")
    quit(0)
