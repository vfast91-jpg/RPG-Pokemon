extends "res://scripts/demo_route_boss_reinforcement_v1.gd"

# Etappe 50: Spiegelkampf gegen Ditto.
#
# Die Gegnergruppe spiegelt exakt die aktuell belegten Teamplaetze (maximal vier).
# Jedes Ditto startet auf dem Level des hoechstleveligen eigenen Pokemon +1.
# Die normale gruppengroessenabhaengige Gegner-Levelkorrektur wird fuer diesen
# festen Kampf bewusst nicht verwendet. Anschliessend greift wie bei allen
# anderen Gegnern die bereits zentrale Routenschwierigkeit.
#
# Die eigentliche Verwandlung findet absichtlich erst im Battle-Layer statt:
# Dadurch werden echte Ditto-Kampfteilnehmer mit eigenen KP und eigenem Level
# erzeugt, bevor die vorhandene Wandler-Mechanik ihre Kampfform kopiert.

const STAGE50_MIRROR_STAGE: int = 50
const STAGE50_MIRROR_MAX_SLOTS: int = 4
const STAGE50_MIRROR_LEVEL_BONUS: int = 1
const STAGE50_MIRROR_SPECIES_ID: String = "ditto"
const STAGE50_MIRROR_MARKER: String = "stage50_mirror"
const STAGE50_MIRROR_TARGET_SLOT: String = "stage50_mirror_target_slot"


func _enemy_party_for_stage(current_stage: int) -> Array:
    if current_stage != STAGE50_MIRROR_STAGE:
        return super._enemy_party_for_stage(current_stage)

    var base_level: int = clampi(
        _highest_team_level() + STAGE50_MIRROR_LEVEL_BONUS,
        1,
        100
    )
    var result: Array = []

    # Use the same compact local slot order that the route battle uses when it
    # builds player_team. Route team entries are Dictionaries in normal play;
    # invalid entries are skipped defensively instead of creating an orphan Ditto.
    for member_value: Variant in team:
        if not (member_value is Dictionary):
            continue
        if result.size() >= STAGE50_MIRROR_MAX_SLOTS:
            break

        var target_slot: int = result.size()
        result.append({
            "species_id": STAGE50_MIRROR_SPECIES_ID,
            "level": base_level,
            STAGE50_MIRROR_MARKER: true,
            STAGE50_MIRROR_TARGET_SLOT: target_slot
        })

    # A valid route always has at least one team member. Keep a defensive
    # fallback so corrupt/legacy state can never turn stage 50 into an auto-win.
    if result.is_empty():
        return super._enemy_party_for_stage(current_stage)

    return _apply_route_difficulty(result)
