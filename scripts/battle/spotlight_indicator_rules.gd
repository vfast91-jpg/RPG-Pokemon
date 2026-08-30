extends RefCounted
class_name SpotlightIndicatorRules


static func is_active(combatant: Dictionary, action_serial: int) -> bool:
    if not bool(combatant.get("alive", false)):
        return false

    # The current database runtime stores Spotlight/redirect duration as an
    # absolute action-serial boundary. If this field exists it is authoritative,
    # including its expired state, so an older compatibility field cannot create
    # a ghost indicator after the real effect has ended.
    if combatant.has("db_redirect_expires"):
        return int(combatant.get("db_redirect_expires", 0)) > action_serial

    # Compatibility fallback for older/newer combatants that still expose the
    # redirect as a remaining-action counter inside the generic effect bucket.
    var effects_value: Variant = combatant.get("effects", {})
    if effects_value is Dictionary:
        return int((effects_value as Dictionary).get("redirect_actions", 0)) > 0

    return false
