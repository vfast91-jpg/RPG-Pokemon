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
    assert(is_equal_approx(StatusEffects.damage_reduction_multiplier(75.0), 0.50))
    assert(is_equal_approx(StatusEffects.additive_damage_multiplier(75.0, 0.6), 1.30))
    assert(is_equal_approx(StatusEffects.atb_start_percent(75.0, 0.5), 25.0))
    assert(is_equal_approx(StatusEffects.next_cycle_multiplier(75.0, 0.5), sqrt(0.5)))
    assert(is_equal_approx(StatusEffects.critical_bonus_fraction(75.0, 0.5), 0.25))
    assert(is_equal_approx(StatusEffects.critical_bonus_fraction(75.0, 1.0), 0.50))

    # The active battle scene must load the migration layer, not the old leaf directly.
    var main_text: String = FileAccess.get_file_as_string("res://main.tscn")
    assert(
        main_text.contains("battle_demo_status_effect_migration_v1.gd"),
        "main.tscn muss die aktive Status-Migrationsruntime laden."
    )
    assert(
        load("res://scripts/battle_demo_status_effect_migration_v1.gd") != null,
        "Die aktive Status-Migrationsruntime muss ohne Parserfehler ladbar sein."
    )

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
