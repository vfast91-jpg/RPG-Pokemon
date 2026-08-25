extends "res://scripts/demo_route_rebalance_v1.gd"

# Phase F: the old TM-only event becomes a six-choice Fundstelle.
# The existing TM compatibility and assignment pipeline is reused unchanged;
# healing items are consumed immediately and vitamins are permanent individual
# route-member bonuses (never species-base-stat edits).

const VITAMIN_BONUS_PER_USE: int = 1
const VITAMIN_STAT_CAP: int = 10
const VITAMINS: Array[Dictionary] = [
    {"id": "protein", "name": "Protein", "stat": "attack", "label": "Angriff", "emoji": "⚔️"},
    {"id": "iron", "name": "Eisen", "stat": "defense", "label": "Verteidigung", "emoji": "🛡️"},
    {"id": "calcium", "name": "Kalzium", "stat": "special", "label": "Status", "emoji": "🔮"},
    {"id": "carbos", "name": "Carbon", "stat": "speed", "label": "Initiative", "emoji": "⚡"},
    {"id": "zinc", "name": "Zink", "stat": "hp", "label": "KP", "emoji": "❤️"}
]

var _fundstelle_active: bool = false
var _fundstelle_tm_offers: Array[Dictionary] = []
var _fundstelle_vitamin_offers: Array[Dictionary] = []


func start_route() -> void:
    _reset_fundstelle_state()
    super.start_route()


func _show_stage_choices(message: String = "") -> void:
    _reset_fundstelle_state()
    super._show_stage_choices(message)


func _reset_fundstelle_state() -> void:
    _fundstelle_active = false
    _fundstelle_tm_offers.clear()
    _fundstelle_vitamin_offers.clear()


func _choices_for_stage(current_stage: int) -> Array[Dictionary]:
    var choices: Array[Dictionary] = super._choices_for_stage(current_stage)
    for choice: Dictionary in choices:
        if str(choice.get("kind", "")) == EVENT_TM:
            choice["label"] = "🎁 Fundstelle"
            choice["hint"] = "Wähle genau eine Belohnung: 3 passende TMs, 1 Heilitem oder 1 von 2 Vitaminen."
    return choices


func _begin_tm_event() -> void:
    # Until Phase G removes the Dangerous Path completely, keep its promised
    # post-battle TM reward on the old dedicated flow. Only a normal item event
    # is transformed into the Fundstelle here.
    if _dangerous_tm_reward_pending:
        super._begin_tm_event()
        return
    _begin_fundstelle()


func _begin_fundstelle() -> void:
    if _tm_catalog.is_empty():
        _reload_tm_catalog()

    _fundstelle_active = true
    _fundstelle_tm_offers.clear()
    _fundstelle_vitamin_offers.clear()

    var tm_candidates: Array[Dictionary] = _eligible_tm_entries()
    tm_candidates.shuffle()
    for index: int in range(mini(TM_OFFER_COUNT, tm_candidates.size())):
        _fundstelle_tm_offers.append(tm_candidates[index])

    var vitamin_candidates: Array[Dictionary] = _viable_vitamin_candidates()
    vitamin_candidates.shuffle()
    for index: int in range(mini(2, vitamin_candidates.size())):
        _fundstelle_vitamin_offers.append(vitamin_candidates[index])

    _show_fundstelle_options()


func _show_fundstelle_options() -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    _active_tm_offers = _fundstelle_tm_offers.duplicate(true)

    var heal_item: Dictionary = _healing_item_for_stage(stage)
    event_label.text = (
        "[b]🎁 Fundstelle[/b]\n"
        + "Wähle genau [b]eine[/b] Belohnung. Heilitems werden sofort benutzt; "
        + "Vitamine verbessern dauerhaft genau ein Pokémon."
    )

    for entry: Dictionary in _fundstelle_tm_offers:
        var recipients: Array[Dictionary] = _tm_recipients(entry)
        if recipients.is_empty():
            continue
        var tm_button := Button.new()
        tm_button.text = "💿 TM · %s" % str(entry.get("name", entry.get("move_id", "TM")))
        tm_button.custom_minimum_size = Vector2(0, 27)
        tm_button.tooltip_text = _tm_offer_tooltip(entry, recipients)
        tm_button.pressed.connect(_choose_tm_offer.bind(entry))
        capture_actions.add_child(tm_button)

    var heal_button := Button.new()
    heal_button.text = "🧪 %s · %s" % [
        str(heal_item.get("name", "Trank")),
        str(heal_item.get("display", "Heilung"))
    ]
    heal_button.custom_minimum_size = Vector2(0, 27)
    heal_button.tooltip_text = "Sofort auf genau ein kampffähiges Team-Pokémon anwenden. Das Item wird nicht eingelagert."
    heal_button.pressed.connect(_choose_healing_item.bind(heal_item))
    capture_actions.add_child(heal_button)

    for vitamin: Dictionary in _fundstelle_vitamin_offers:
        var vitamin_button := Button.new()
        vitamin_button.text = "%s %s · +%d %s" % [
            str(vitamin.get("emoji", "✨")),
            str(vitamin.get("name", "Vitamin")),
            VITAMIN_BONUS_PER_USE,
            str(vitamin.get("label", "Wert"))
        ]
        vitamin_button.custom_minimum_size = Vector2(0, 27)
        vitamin_button.tooltip_text = (
            "Dauerhaft +%d %s für ein Pokémon. Pro Pokémon und Attribut sind maximal +%d Vitaminpunkte möglich."
            % [VITAMIN_BONUS_PER_USE, str(vitamin.get("label", "Wert")), VITAMIN_STAT_CAP]
        )
        vitamin_button.pressed.connect(_choose_vitamin.bind(vitamin))
        capture_actions.add_child(vitamin_button)

    if _fundstelle_tm_offers.size() < TM_OFFER_COUNT:
        var info := Label.new()
        info.text = "Hinweis: Für dein aktuelles Team sind nur %d noch nutzbare TM-Angebote verfügbar." % _fundstelle_tm_offers.size()
        info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        info.add_theme_font_size_override("font_size", 8)
        info.add_theme_color_override("font_color", Color("b8d3c7"))
        capture_actions.add_child(info)


func _show_tm_offer_buttons() -> void:
    if _fundstelle_active and not _dangerous_tm_reward_pending:
        _show_fundstelle_options()
        return
    super._show_tm_offer_buttons()


func _assign_tm(entry: Dictionary, team_index: int) -> void:
    var was_fundstelle: bool = _fundstelle_active and not _dangerous_tm_reward_pending
    super._assign_tm(entry, team_index)
    if not was_fundstelle:
        return
    _fundstelle_active = false
    _fundstelle_tm_offers.clear()
    _fundstelle_vitamin_offers.clear()
    event_label.text = "[b]🎁 Fundstelle[/b]\n" + event_label.text


func _healing_item_for_stage(current_stage: int) -> Dictionary:
    if current_stage <= 20:
        return {"id": "potion", "name": "Trank", "amount": 20, "display": "+20 KP"}
    if current_stage <= 40:
        return {"id": "super_potion", "name": "Supertrank", "amount": 50, "display": "+50 KP"}
    if current_stage <= 60:
        return {"id": "hyper_potion", "name": "Hypertrank", "amount": 120, "display": "+120 KP"}
    return {"id": "max_potion", "name": "Top-Trank", "amount": -1, "display": "volle KP"}


func _choose_healing_item(item: Dictionary) -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    event_label.text = "[b]🧪 %s[/b]\nAuf welches kampffähige Pokémon möchtest du das Heilitem jetzt anwenden?" % str(item.get("name", "Trank"))

    var recipient_count: int = 0
    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        if int(member.get("hp", 0)) <= 0:
            continue
        recipient_count += 1
        var button := Button.new()
        button.text = "%s · %d/%d KP" % [
            str(member.get("name", "Pokémon")),
            int(member.get("hp", 0)),
            int(member.get("max_hp", 1))
        ]
        button.custom_minimum_size = Vector2(0, 27)
        button.pressed.connect(_apply_healing_item.bind(index, item))
        capture_actions.add_child(button)

    if recipient_count == 0:
        event_label.text += "\nEs gibt derzeit kein kampffähiges Ziel für dieses Heilitem."

    var back_button := Button.new()
    back_button.text = "ZURÜCK ZUR FUNDSTELLE"
    back_button.pressed.connect(_show_fundstelle_options)
    capture_actions.add_child(back_button)


func _apply_healing_item(team_index: int, item: Dictionary) -> void:
    if team_index < 0 or team_index >= team.size():
        _show_fundstelle_options()
        return
    var member_value: Variant = team[team_index]
    if not (member_value is Dictionary):
        _show_fundstelle_options()
        return
    var member: Dictionary = member_value
    var old_hp: int = int(member.get("hp", 0))
    if old_hp <= 0:
        _choose_healing_item(item)
        return

    var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
    var amount: int = int(item.get("amount", 0))
    var new_hp: int = max_hp if amount < 0 else mini(max_hp, old_hp + maxi(0, amount))
    member["hp"] = new_hp
    team[team_index] = member

    _fundstelle_active = false
    _clear_container(capture_actions)
    continue_button.visible = true
    event_label.text = (
        "[b]🎁 Fundstelle · %s benutzt[/b]\n%s erhält %d KP zurück und hat jetzt %d/%d KP."
        % [str(item.get("name", "Trank")), str(member.get("name", "Pokémon")), maxi(0, new_hp - old_hp), new_hp, max_hp]
    )
    _refresh_team_panel()


func _viable_vitamin_candidates() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for vitamin: Dictionary in VITAMINS:
        var stat_key: String = str(vitamin.get("stat", ""))
        for member_value: Variant in team:
            if not (member_value is Dictionary):
                continue
            var bonuses: Dictionary = _vitamin_bonuses_for_member(member_value as Dictionary)
            if int(bonuses.get(stat_key, 0)) < VITAMIN_STAT_CAP:
                result.append(vitamin.duplicate(true))
                break
    return result


func _choose_vitamin(vitamin: Dictionary) -> void:
    _clear_container(capture_actions)
    continue_button.visible = false
    var stat_key: String = str(vitamin.get("stat", ""))
    event_label.text = "[b]%s %s[/b]\nWelches Pokémon soll dauerhaft +%d %s erhalten?" % [
        str(vitamin.get("emoji", "✨")),
        str(vitamin.get("name", "Vitamin")),
        VITAMIN_BONUS_PER_USE,
        str(vitamin.get("label", "Wert"))
    ]

    for index: int in range(team.size()):
        var member_value: Variant = team[index]
        if not (member_value is Dictionary):
            continue
        var member: Dictionary = member_value
        var bonuses: Dictionary = _vitamin_bonuses_for_member(member)
        var current_bonus: int = int(bonuses.get(stat_key, 0))
        if current_bonus >= VITAMIN_STAT_CAP:
            continue

        var button := Button.new()
        button.text = "%s · Vitaminbonus %s +%d/%d" % [
            str(member.get("name", "Pokémon")),
            str(vitamin.get("label", "Wert")),
            current_bonus,
            VITAMIN_STAT_CAP
        ]
        button.custom_minimum_size = Vector2(0, 27)
        button.pressed.connect(_apply_vitamin.bind(index, vitamin))
        capture_actions.add_child(button)

    var back_button := Button.new()
    back_button.text = "ZURÜCK ZUR FUNDSTELLE"
    back_button.pressed.connect(_show_fundstelle_options)
    capture_actions.add_child(back_button)


func _apply_vitamin(team_index: int, vitamin: Dictionary) -> void:
    if team_index < 0 or team_index >= team.size():
        _show_fundstelle_options()
        return
    var member_value: Variant = team[team_index]
    if not (member_value is Dictionary):
        _show_fundstelle_options()
        return

    var member: Dictionary = member_value
    var stat_key: String = str(vitamin.get("stat", ""))
    var bonuses: Dictionary = _vitamin_bonuses_for_member(member)
    var old_bonus: int = int(bonuses.get(stat_key, 0))
    if old_bonus >= VITAMIN_STAT_CAP:
        _choose_vitamin(vitamin)
        return

    var new_bonus: int = mini(VITAMIN_STAT_CAP, old_bonus + VITAMIN_BONUS_PER_USE)
    var gained: int = new_bonus - old_bonus
    bonuses[stat_key] = new_bonus
    member["vitamin_bonuses"] = bonuses

    if stat_key == "hp" and gained > 0:
        var old_max_hp: int = maxi(1, int(member.get("max_hp", 1)))
        var old_hp: int = clampi(int(member.get("hp", 0)), 0, old_max_hp)
        member["max_hp"] = old_max_hp + gained
        member["hp"] = 0 if old_hp <= 0 else old_hp + gained

    team[team_index] = member
    _fundstelle_active = false
    _clear_container(capture_actions)
    continue_button.visible = true
    event_label.text = (
        "[b]🎁 Fundstelle · %s[/b]\n%s erhält dauerhaft [b]+%d %s[/b]. "
        + "Vitaminbonus für dieses Attribut: +%d/%d."
    ) % [
        str(vitamin.get("name", "Vitamin")),
        str(member.get("name", "Pokémon")),
        gained,
        str(vitamin.get("label", "Wert")),
        new_bonus,
        VITAMIN_STAT_CAP
    ]
    _refresh_team_panel()


func _vitamin_bonuses_for_member(member: Dictionary) -> Dictionary:
    var value: Variant = member.get("vitamin_bonuses", {})
    var bonuses: Dictionary = value.duplicate(true) if value is Dictionary else {}
    for stat_key: String in ["hp", "attack", "defense", "special", "speed"]:
        bonuses[stat_key] = clampi(int(bonuses.get(stat_key, 0)), 0, VITAMIN_STAT_CAP)
    return bonuses


func _route_member_stats(member: Dictionary) -> Dictionary:
    var stats: Dictionary = super._route_member_stats(member)
    var bonuses: Dictionary = _vitamin_bonuses_for_member(member)
    stats["max_hp"] = int(stats.get("max_hp", member.get("max_hp", 1))) + int(bonuses.get("hp", 0))
    stats["attack"] = int(stats.get("attack", 0)) + int(bonuses.get("attack", 0))
    stats["defense"] = int(stats.get("defense", 0)) + int(bonuses.get("defense", 0))
    stats["special"] = int(stats.get("special", 0)) + int(bonuses.get("special", 0))
    stats["speed"] = int(stats.get("speed", 0)) + int(bonuses.get("speed", 0))
    return stats


func _award_experience(amount: int) -> Array[String]:
    var hp_snapshots: Array[Dictionary] = []
    for member_value: Variant in team:
        if not (member_value is Dictionary):
            hp_snapshots.append({})
            continue
        var member: Dictionary = member_value
        var bonuses: Dictionary = _vitamin_bonuses_for_member(member)
        var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
        var hp: int = clampi(int(member.get("hp", 0)), 0, max_hp)
        hp_snapshots.append({
            "hp_bonus": int(bonuses.get("hp", 0)),
            "was_alive": hp > 0,
            "damage": maxi(0, max_hp - hp)
        })

    var messages: Array[String] = super._award_experience(amount)

    for index: int in range(mini(team.size(), hp_snapshots.size())):
        var snapshot: Dictionary = hp_snapshots[index]
        if int(snapshot.get("hp_bonus", 0)) <= 0:
            continue
        _repair_member_hp_vitamin(
            index,
            int(snapshot.get("damage", 0)),
            bool(snapshot.get("was_alive", false))
        )

    _refresh_team_panel()
    return messages


func _apply_evolution_target(
    index: int,
    before_species_id: String,
    target_species_id: String,
    level: int
) -> Dictionary:
    var prior_damage: int = 0
    var was_alive: bool = false
    var had_hp_bonus: bool = false
    if index >= 0 and index < team.size():
        var member_value: Variant = team[index]
        if member_value is Dictionary:
            var member: Dictionary = member_value
            var bonuses: Dictionary = _vitamin_bonuses_for_member(member)
            had_hp_bonus = int(bonuses.get("hp", 0)) > 0
            var max_hp: int = maxi(1, int(member.get("max_hp", 1)))
            var hp: int = clampi(int(member.get("hp", 0)), 0, max_hp)
            was_alive = hp > 0
            prior_damage = maxi(0, max_hp - hp)

    var result: Dictionary = super._apply_evolution_target(index, before_species_id, target_species_id, level)
    if not result.is_empty() and had_hp_bonus:
        _repair_member_hp_vitamin(index, prior_damage, was_alive)
    return result


func _repair_member_hp_vitamin(index: int, prior_damage: int, was_alive: bool) -> void:
    if index < 0 or index >= team.size():
        return
    var member_value: Variant = team[index]
    if not (member_value is Dictionary):
        return
    var member: Dictionary = member_value
    var bonuses: Dictionary = _vitamin_bonuses_for_member(member)
    var hp_bonus: int = int(bonuses.get("hp", 0))
    if hp_bonus <= 0:
        return

    var base_max_hp: int = maxi(1, int(member.get("max_hp", 1)) - hp_bonus)
    if battle_demo != null and battle_demo.has_method("route_stat_snapshot"):
        var snapshot_value: Variant = battle_demo.route_stat_snapshot(
            str(member.get("species_id", "")),
            maxi(1, int(member.get("level", 1)))
        )
        if snapshot_value is Dictionary:
            base_max_hp = maxi(1, int((snapshot_value as Dictionary).get("max_hp", base_max_hp)))

    var effective_max_hp: int = base_max_hp + hp_bonus
    member["max_hp"] = effective_max_hp
    member["hp"] = 0 if not was_alive else clampi(effective_max_hp - maxi(0, prior_damage), 1, effective_max_hp)
    team[index] = member
