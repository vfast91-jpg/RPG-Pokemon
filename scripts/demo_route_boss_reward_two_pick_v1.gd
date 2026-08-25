extends "res://scripts/demo_route_viewport_guard_v1.gd"

# Boss-Fundstelle reward layer.
#
# Normal Fundstellen remain unchanged: one successful reward choice.
# A Fundstelle earned after a successful Besondere Begegnung uses the exact
# same rolled reward set, but the player may take two successful rewards from it.
# Non-TM rewards may be chosen twice. A TM offer is consumed after it is actually
# assigned to a Pokemon, so the second choice may only use the remaining TM offers.
#
# The rolled offers and the remaining-choice counter are regular script state so
# RunSaveManager persists them. This prevents reroll/reload exploits between the
# first and second boss reward.

const BOSS_FUNDSTELLE_PICK_COUNT: int = 2

var _boss_fundstelle_choices_remaining: int = 0
var _boss_fundstelle_last_reward: String = ""
var _boss_fundstelle_final_reward_text: String = ""
var _boss_fundstelle_consumed_tm_keys: Array[String] = []


func _reset_fundstelle_state() -> void:
    super._reset_fundstelle_state()
    _clear_boss_fundstelle_choice_state()


func _clear_boss_fundstelle_choice_state() -> void:
    _boss_fundstelle_choices_remaining = 0
    _boss_fundstelle_last_reward = ""
    _boss_fundstelle_final_reward_text = ""
    _boss_fundstelle_consumed_tm_keys.clear()


func _begin_fundstelle() -> void:
    if _boss_fundstelle_pending:
        _boss_fundstelle_choices_remaining = BOSS_FUNDSTELLE_PICK_COUNT
        _boss_fundstelle_last_reward = ""
        _boss_fundstelle_final_reward_text = ""
        _boss_fundstelle_consumed_tm_keys.clear()
    else:
        _clear_boss_fundstelle_choice_state()

    super._begin_fundstelle()


func _show_fundstelle_options() -> void:
    if _boss_fundstelle_pending and _boss_fundstelle_choices_remaining > 0:
        _fundstelle_active = true
        _remove_consumed_boss_tm_offers()

    super._show_fundstelle_options()

    if not _boss_fundstelle_pending or _boss_fundstelle_choices_remaining <= 0:
        return

    var choice_text: String
    if _boss_fundstelle_choices_remaining >= BOSS_FUNDSTELLE_PICK_COUNT:
        choice_text = (
            "Du darfst nach diesem Bosskampf [b]zwei[/b] Belohnungen aus genau dieser Fundstelle wählen."
        )
    else:
        choice_text = "Erste Belohnung erhalten. Wähle jetzt noch [b]eine weitere[/b] Belohnung."

    var last_reward_text: String = ""
    if not _boss_fundstelle_last_reward.is_empty():
        last_reward_text = "\nZuletzt erhalten: [b]%s[/b]." % _boss_fundstelle_last_reward

    event_label.text = (
        _boss_reward_summary
        + "\n\n[b]🎁 Fundstelle · Bossbelohnung[/b]\n"
        + choice_text
        + last_reward_text
        + "\nHeilitem, Beleber und Vitamin dürfen erneut gewählt werden. "
        + "Eine bereits vergebene TM ist für die zweite Auswahl verbraucht."
    )


func _assign_tm(entry: Dictionary, team_index: int) -> void:
    if not _boss_double_reward_is_active():
        super._assign_tm(entry, team_index)
        return

    var saved_tm_offers: Array[Dictionary] = _fundstelle_tm_offers.duplicate(true)
    var saved_vitamin_offers: Array[Dictionary] = _fundstelle_vitamin_offers.duplicate(true)
    var used_tm_key: String = _fundstelle_tm_offer_key(entry)

    # Suppress the inherited one-pick boss completion while the mature TM
    # assignment pipeline performs compatibility checks and writes the move.
    _boss_fundstelle_pending = false
    super._assign_tm(entry, team_index)
    _boss_fundstelle_pending = true

    if not _fundstelle_reward_application_succeeded():
        return

    var reward_text: String = event_label.text
    var reward_label: String = "💿 TM · %s" % str(entry.get("name", entry.get("move_id", "TM")))
    var has_more_choices: bool = _consume_boss_fundstelle_pick(reward_label)

    if has_more_choices:
        _fundstelle_tm_offers.clear()
        for offer: Dictionary in saved_tm_offers:
            if _fundstelle_tm_offer_key(offer) != used_tm_key:
                _fundstelle_tm_offers.append(offer)
        _fundstelle_vitamin_offers = saved_vitamin_offers.duplicate(true)

        if not used_tm_key.is_empty() and not _boss_fundstelle_consumed_tm_keys.has(used_tm_key):
            _boss_fundstelle_consumed_tm_keys.append(used_tm_key)

        _fundstelle_active = true
        continue_button.visible = false
        _show_fundstelle_options()
        return

    _boss_fundstelle_final_reward_text = reward_text
    _prepare_boss_reward_finish(reward_text)


func _apply_healing_item(team_index: int, item: Dictionary) -> void:
    if not _boss_double_reward_is_active():
        super._apply_healing_item(team_index, item)
        return

    _boss_fundstelle_pending = false
    super._apply_healing_item(team_index, item)
    _boss_fundstelle_pending = true

    if not _fundstelle_reward_application_succeeded():
        return

    var reward_text: String = event_label.text
    var reward_label: String = "🧪 %s" % str(item.get("name", "Heilitem"))
    if _consume_boss_fundstelle_pick(reward_label):
        _fundstelle_active = true
        continue_button.visible = false
        _show_fundstelle_options()
        return

    _boss_fundstelle_final_reward_text = reward_text
    _prepare_boss_reward_finish(reward_text)


func _apply_vitamin(team_index: int, vitamin: Dictionary) -> void:
    if not _boss_double_reward_is_active():
        super._apply_vitamin(team_index, vitamin)
        return

    _boss_fundstelle_pending = false
    super._apply_vitamin(team_index, vitamin)
    _boss_fundstelle_pending = true

    if not _fundstelle_reward_application_succeeded():
        return

    var reward_text: String = event_label.text
    var reward_label: String = "%s %s" % [
        str(vitamin.get("emoji", "✨")),
        str(vitamin.get("name", "Vitamin"))
    ]
    if _consume_boss_fundstelle_pick(reward_label):
        _fundstelle_active = true
        continue_button.visible = false
        _show_fundstelle_options()
        return

    _boss_fundstelle_final_reward_text = reward_text
    _prepare_boss_reward_finish(reward_text)


func _apply_revive(team_index: int) -> void:
    if not _boss_double_reward_is_active():
        super._apply_revive(team_index)
        return

    _boss_fundstelle_pending = false
    super._apply_revive(team_index)
    _boss_fundstelle_pending = true

    if not _fundstelle_reward_application_succeeded():
        return

    var reward_text: String = event_label.text
    if _consume_boss_fundstelle_pick("✨ Beleber"):
        _fundstelle_active = true
        continue_button.visible = false
        _show_fundstelle_options()
        return

    _boss_fundstelle_final_reward_text = reward_text
    _prepare_boss_reward_finish(reward_text)


func _boss_double_reward_is_active() -> bool:
    return (
        _boss_fundstelle_pending
        and _fundstelle_active
        and _boss_fundstelle_choices_remaining > 0
    )


func _fundstelle_reward_application_succeeded() -> bool:
    return (
        continue_button != null
        and continue_button.visible
        and not _fundstelle_active
    )


func _consume_boss_fundstelle_pick(reward_label: String) -> bool:
    if _boss_fundstelle_choices_remaining <= 0:
        return false

    _boss_fundstelle_choices_remaining = maxi(0, _boss_fundstelle_choices_remaining - 1)
    _boss_fundstelle_last_reward = reward_label
    return _boss_fundstelle_choices_remaining > 0


func _fundstelle_tm_offer_key(entry: Dictionary) -> String:
    var number: String = str(entry.get("number", "")).strip_edges()
    var move_id: String = str(entry.get("move_id", "")).strip_edges()
    if number.is_empty() and move_id.is_empty():
        return ""
    return number + "|" + move_id


func _remove_consumed_boss_tm_offers() -> void:
    if _boss_fundstelle_consumed_tm_keys.is_empty() or _fundstelle_tm_offers.is_empty():
        return

    var remaining_offers: Array[Dictionary] = []
    for offer: Dictionary in _fundstelle_tm_offers:
        if not _boss_fundstelle_consumed_tm_keys.has(_fundstelle_tm_offer_key(offer)):
            remaining_offers.append(offer)

    _fundstelle_tm_offers.clear()
    for offer: Dictionary in remaining_offers:
        _fundstelle_tm_offers.append(offer)
