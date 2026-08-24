extends "res://scripts/battle_demo_sandshrew_hit_aggro_integrity_v1.gd"

# Player-facing explanation for the Horter / Verzehrer / Entfessler combo.
#
# The generic effect registry deliberately uses short labels because the same
# labels are reused by compact UI surfaces. For these three linked moves that
# loses the information a player actually needs: Horter creates a resource and
# the other two moves consume it. Keep the combat rules untouched and explain
# that relationship only in the move preview / tooltip summary.


func _compact_effect_summary(move: Dictionary) -> String:
    match str(move.get("id", "")):
        "stockpile":
            return (
                "Sammelt 1 Horter-Ladung (max. 3). Jede Ladung erhöht die "
                + "Verteidigung; die Stärke des Bonus hängt vom Statuswert ab. "
                + "Die Ladungen können später von Verzehrer oder Entfessler "
                + "verbraucht werden."
            )
        "swallow":
            return (
                "Verbraucht alle Horter-Ladungen und heilt den Anwender. Mehr "
                + "Ladungen und ein höherer Statuswert bedeuten mehr Heilung. "
                + "Ohne Horter-Ladung schlägt Verzehrer fehl; der durch Horter "
                + "aufgebaute Verteidigungsbonus endet."
            )
        "spit_up":
            return (
                "Verbraucht alle Horter-Ladungen für einen Angriff: 1/2/3 "
                + "Ladungen → Stärke 100/200/300. Ohne Horter-Ladung schlägt "
                + "Entfessler fehl; der durch Horter aufgebaute "
                + "Verteidigungsbonus endet."
            )
    return super._compact_effect_summary(move)
