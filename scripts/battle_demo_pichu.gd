extends "res://scripts/battle_demo.gd"

# Pichu replaces the old Pikachu demo slot. Values and level-up moves are
# sourced from the project Pokémon/attack databases. The base combat lab stays
# untouched so this override remains easy to remove once the generated data
# pipeline writes Pichu directly into combat_lab_data.json.

func _load_data() -> void:
    super._load_data()
    if data.is_empty():
        return

    var species: Dictionary = data.get("species", {})
    species.erase("pikachu")
    species["pichu"] = {
        "id": "pichu",
        "name": "Pichu",
        "types": ["electric"],
        "base_stats": {"hp": 20, "attack": 38, "defense": 28, "special": 33, "speed": 60},
        "learnset": [
            {"level": 1, "moves": ["tail_whip", "thunder_shock"]},
            {"level": 4, "moves": ["play_nice"]},
            {"level": 8, "moves": ["sweet_kiss"]}
        ]
    }
    data["species"] = species

    var moves: Dictionary = data.get("moves", {})
    moves["thunder_shock"] = {
        "id": "thunder_shock",
        "name": "Donnerschock",
        "type": "electric",
        "category": "special",
        "power": 40,
        "accuracy": 100,
        "ap": 3,
        "target": "enemy_highest_aggro",
        "area": false,
        "priority": 0,
        "opening": false,
        "mechanics": [
            {"kind": "damage"},
            {"kind": "status", "status": "paralysis", "chance": 0.10}
        ]
    }
    moves["play_nice"] = {
        "id": "play_nice",
        "name": "Kameradschaft",
        "type": "normal",
        "category": "status",
        "power": null,
        "accuracy": null,
        "ap": 5,
        "target": "enemy_highest_aggro",
        "area": false,
        "priority": 0,
        "opening": false,
        "mechanics": [
            {"kind": "outgoing_damage_mod", "scope": "enemy_highest_aggro", "multiplier_from_special": -1.0, "uses_special_percent": true, "duration": "next_damage"}
        ]
    }
    moves["sweet_kiss"] = {
        "id": "sweet_kiss",
        "name": "Bitterkuss",
        "type": "fairy",
        "category": "status",
        "power": null,
        "accuracy": 75,
        "ap": 7,
        "target": "enemy_highest_aggro",
        "area": false,
        "priority": 0,
        "opening": false,
        "mechanics": [
            {"kind": "status", "status": "confusion", "chance": 1.0}
        ]
    }
    data["moves"] = moves

    var next_order: Array = []
    for sid in data.get("species_order", []):
        if str(sid) != "pikachu":
            next_order.append(sid)
    if not next_order.has("pichu"):
        next_order.append("pichu")
    species_ids = next_order
    data["species_order"] = next_order.duplicate()


func _init_setup() -> void:
    player_setup = [{"species_id": "pichu", "level": 5}]
    enemy_setup = [{"species_id": "pichu", "level": 5}]


func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    if str(mechanic.get("kind", "")) == "status" and str(mechanic.get("status", "")) == "confusion":
        if randf() <= float(mechanic.get("chance", 1.0)):
            target["confused_turns"] = randi_range(1, 4)
            return 3.0
        return 0.0
    return super._effect(actor, target, mechanic)


func _execute_move(actor: Dictionary, move_id: String) -> void:
    var confused_turns := int(actor.get("confused_turns", 0))
    if confused_turns > 0:
        actor["confused_turns"] = confused_turns - 1
        if randf() < 0.33:
            actor["atb"] = 0.0
            actor["cycle"] = 1.0
            var damage := _damage(actor, actor, 40, "typeless")
            actor["hp"] = maxi(0, int(actor["hp"]) - damage)
            if int(actor["hp"]) <= 0:
                actor["alive"] = false
            _set_log(_actor_name(actor) + " ist verwirrt und verletzt sich selbst → " + str(damage) + " Schaden.")
            _refresh_cards()
            _check_end()
            return
    super._execute_move(actor, move_id)


func _refresh_cards() -> void:
    super._refresh_cards()
    for combatant in combatants:
        var turns := int(combatant.get("confused_turns", 0))
        if turns <= 0:
            continue
        var ui: Dictionary = cards.get(str(combatant["id"]), {})
        if not ui.is_empty():
            ui["status"].text += " · VERW " + str(turns)
