extends SceneTree

const RunSaveManagerScript = preload("res://scripts/run_save_manager.gd")
const TEST_SAVE_PATH: String = "user://timeflow_run_save_test.dat"


class DummyRoute:
    extends Node

    # Deliberately normal runtime members, not @export variables. This is the
    # exact category that the broken PROPERTY_USAGE_STORAGE filter skipped.
    var stage: int = 3
    var team: Array = [{
        "species_id": "zapdos",
        "name": "Zapdos",
        "level": 18,
        "hp": 63,
        "max_hp": 70,
        "xp": 17,
        "moves": ["thundershock", "peck"]
    }]
    var storage: Array = [{"species_id": "pikachu", "level": 11}]
    var pending_capture: Dictionary = {}
    var stage_xp_multiplier: float = 1.25
    var last_route_message: String = "Etappe 2 geschafft"
    var saved_special_battle_kind: String = "rare"
    var saved_special_enemy_party: Array = [{"species_id": "raichu", "level": 23, "boss": true}]
    var saved_special_battle_heading: String = "👑 Besondere Begegnung"

    # Boss-Fundstelle state: after reward 1 the exact remaining offers and the
    # one remaining pick must survive a save/restore without a reroll.
    var _boss_fundstelle_pending: bool = true
    var _boss_fundstelle_choices_remaining: int = 1
    var _boss_fundstelle_last_reward: String = "🧪 Supertrank"
    var _boss_fundstelle_final_reward_text: String = ""
    var _boss_fundstelle_consumed_tm_keys: Array[String] = ["024|thunderbolt"]
    var _fundstelle_active: bool = true
    var _fundstelle_tm_offers: Array[Dictionary] = [
        {"number": "006", "move_id": "toxic", "name": "Toxin"},
        {"number": "044", "move_id": "rest", "name": "Erholung"}
    ]
    var _fundstelle_vitamin_offers: Array[Dictionary] = [
        {"id": "protein", "name": "Protein", "stat": "attack"}
    ]


func _initialize() -> void:
    _remove_test_save()

    var manager = RunSaveManagerScript.new()
    manager.save_path = TEST_SAVE_PATH

    var route := DummyRoute.new()
    assert(manager.save_route(route, "boss_fundstelle"), "Run-Save muss normale Runtime-Variablen speichern können.")
    assert(FileAccess.file_exists(TEST_SAVE_PATH), "Run-Save-Datei muss tatsächlich angelegt werden.")
    assert(manager.has_run_save(), "Ein gerade geschriebener Run-Save muss als vorhanden erkannt werden.")
    assert(manager.saved_stage() == 3, "Gespeicherte Etappe muss erhalten bleiben.")
    assert(manager.saved_checkpoint() == "boss_fundstelle", "Boss-Fundstellen-Checkpoint muss erhalten bleiben.")

    var payload: Dictionary = manager.load_run_save()
    var state: Dictionary = payload.get("state", {}) as Dictionary
    assert(int(state.get("stage", 0)) == 3, "Snapshot muss die Etappe enthalten.")
    assert(state.get("team", []) is Array and (state.get("team", []) as Array).size() == 1, "Snapshot muss das Team enthalten.")
    assert(str(((state.get("team", []) as Array)[0] as Dictionary).get("species_id", "")) == "zapdos", "Gefangenes Pokémon muss im Save erhalten bleiben.")
    assert(bool(state.get("_boss_fundstelle_pending", false)), "Offene Boss-Fundstelle muss im Snapshot erhalten bleiben.")
    assert(int(state.get("_boss_fundstelle_choices_remaining", 0)) == 1, "Die noch offene zweite Bossbelohnung muss gespeichert werden.")
    assert(str(state.get("_boss_fundstelle_last_reward", "")) == "🧪 Supertrank", "Die erste Bossbelohnung muss gespeichert werden.")
    assert(
        state.get("_boss_fundstelle_consumed_tm_keys", []) is Array
        and (state.get("_boss_fundstelle_consumed_tm_keys", []) as Array).has("024|thunderbolt"),
        "Eine bereits verbrauchte TM muss fuer den Resume-Zustand gespeichert werden."
    )
    assert(
        state.get("_fundstelle_tm_offers", []) is Array
        and (state.get("_fundstelle_tm_offers", []) as Array).size() == 2,
        "Die verbliebenen TM-Angebote duerfen beim Speichern nicht neu ausgewuerfelt werden."
    )

    route.stage = 99
    route.team.clear()
    route.storage.clear()
    route.stage_xp_multiplier = 1.0
    route._boss_fundstelle_pending = false
    route._boss_fundstelle_choices_remaining = 0
    route._boss_fundstelle_last_reward = ""
    route._boss_fundstelle_consumed_tm_keys.clear()
    route._fundstelle_active = false
    route._fundstelle_tm_offers.clear()
    route._fundstelle_vitamin_offers.clear()

    assert(manager.restore_route(route), "Gespeicherter Run muss wiederhergestellt werden können.")
    assert(route.stage == 3, "Restore muss die gespeicherte Etappe zurücksetzen.")
    assert(route.team.size() == 1, "Restore muss das gespeicherte Team zurückbringen.")
    assert(str((route.team[0] as Dictionary).get("species_id", "")) == "zapdos", "Restore muss das gespeicherte Pokémon zurückbringen.")
    assert(route.storage.size() == 1, "Restore muss auch das Lager zurückbringen.")
    assert(is_equal_approx(route.stage_xp_multiplier, 1.25), "Restore muss Run-Multiplikatoren erhalten.")
    assert(route._boss_fundstelle_pending, "Restore muss die offene Boss-Fundstelle zurückbringen.")
    assert(route._boss_fundstelle_choices_remaining == 1, "Restore muss exakt eine verbleibende Bossauswahl zurückbringen.")
    assert(route._boss_fundstelle_last_reward == "🧪 Supertrank", "Restore muss die erste Bossbelohnung zurückbringen.")
    assert(route._boss_fundstelle_consumed_tm_keys.has("024|thunderbolt"), "Restore muss die verbrauchte TM markieren.")
    assert(route._fundstelle_active, "Restore muss die laufende Fundstelle aktiv halten.")
    assert(route._fundstelle_tm_offers.size() == 2, "Restore muss exakt dieselben verbleibenden TM-Angebote zurückbringen.")
    assert(str(route._fundstelle_tm_offers[0].get("move_id", "")) == "toxic", "Restore darf das erste verbleibende TM-Angebot nicht rerollen.")
    assert(str(route._fundstelle_tm_offers[1].get("move_id", "")) == "rest", "Restore darf das zweite verbleibende TM-Angebot nicht rerollen.")
    assert(route._fundstelle_vitamin_offers.size() == 1, "Restore muss auch das ausgewürfelte Vitamin-Angebot erhalten.")

    manager.clear_run_save()
    assert(not FileAccess.file_exists(TEST_SAVE_PATH), "clear_run_save muss nur die Test-Save-Datei löschen.")

    route.queue_free()
    manager.queue_free()
    print("Run save manager tests: OK")
    quit(0)


func _remove_test_save() -> void:
    if FileAccess.file_exists(TEST_SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
