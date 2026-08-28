extends "res://scripts/demo_route_campfire_v1.gd"

# UI regression guard for the Reisegefaehrten capture choice.
# The underlying capture button was renamed from "INS TEAM AUFNEHMEN" to
# "ALS REISEGEFAEHRTEN AUFNEHMEN". The older polish layer still recognizes
# only the former wording, so the current button otherwise loses its card style.
#
# Gen-2 / Gen-3 encounter integration guard:
# The established rarity layer predates the later generations and therefore only
# loads gen1_species_encounter_families_v1.json. Gen-2 and Gen-3 species are
# already present in the active runtime roster, but without family metadata they
# fall back to a family catch rate of 1.0 and are effectively suppressed by the
# weighted route selection. Merge only the missing later-generation family/
# catch-rate metadata here; the existing rarity curve, stage progression,
# landscape weighting and battle selection remain unchanged.

const GEN2_ENCOUNTER_FAMILY_DATA_PATHS: Array[String] = [
    "res://data/gen2_species_families_01_10_v1.json",
    "res://data/gen2_species_families_11_20_v1.json",
    "res://data/gen2_species_families_21_30_v1.json",
    "res://data/gen2_species_families_31_33_v1.json",
    "res://data/gen2_species_families_34_35_v1.json",
    "res://data/gen2_species_families_36_38_v1.json",
    "res://data/gen2_species_families_39_40_v1.json",
    "res://data/gen2_species_families_41_44_v1.json",
    "res://data/gen2_species_families_45_47_v1.json",
    "res://data/gen2_species_families_48_50_v1.json",
    "res://data/gen2_species_family_51_v1.json"
]

const GEN3_ENCOUNTER_FAMILY_DATA_PATHS: Array[String] = [
    "res://data/gen3_species_families_01_04_v1.json",
    "res://data/gen3_species_families_05_08_v1.json",
    "res://data/gen3_species_families_09_12_v1.json",
    "res://data/gen3_species_families_13_16_v1.json",
    "res://data/gen3_species_families_17_20_v1.json",
    "res://data/gen3_species_families_21_24_v1.json",
    "res://data/gen3_species_families_25_28_v1.json",
    "res://data/gen3_species_families_29_32_v1.json",
    "res://data/gen3_species_families_33_36_v1.json",
    "res://data/gen3_species_families_37_40_v1.json",
    "res://data/gen3_species_families_41_44_v1.json",
    "res://data/gen3_species_families_45_48_v1.json",
    "res://data/gen3_species_families_49_52_v1.json",
    "res://data/gen3_species_families_53_56_v1.json",
    "res://data/gen3_species_families_57_60_v1.json",
    "res://data/gen3_species_families_61_64_v1.json",
    "res://data/gen3_species_families_65_68_v1.json",
    "res://data/gen3_species_families_69_72_v1.json",
    "res://data/gen3_species_families_73_73_v1.json"
]

var _gen2_encounter_family_data_loaded: bool = false
var _gen3_encounter_family_data_loaded: bool = false


func _ensure_encounter_family_data() -> void:
    super._ensure_encounter_family_data()

    if not _gen2_encounter_family_data_loaded:
        _gen2_encounter_family_data_loaded = true
        for data_path: String in GEN2_ENCOUNTER_FAMILY_DATA_PATHS:
            _merge_gen2_encounter_family_data(data_path)

    if not _gen3_encounter_family_data_loaded:
        _gen3_encounter_family_data_loaded = true
        for data_path: String in GEN3_ENCOUNTER_FAMILY_DATA_PATHS:
            _merge_gen3_encounter_family_data(data_path)


func _merge_gen2_encounter_family_data(data_path: String) -> void:
    var file := FileAccess.open(data_path, FileAccess.READ)
    if file == null:
        push_warning("Gen-2-Begegnungsdaten fehlen: " + data_path)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_warning("Gen-2-Begegnungsdaten sind ungültig: " + data_path)
        return

    var species_value: Variant = (parsed as Dictionary).get("species", {})
    if not (species_value is Dictionary):
        push_warning("Gen-2-Begegnungsdaten enthalten keine Species: " + data_path)
        return

    for species_key: Variant in (species_value as Dictionary).keys():
        var entry_value: Variant = (species_value as Dictionary).get(species_key, {})
        if not (entry_value is Dictionary):
            continue

        var entry: Dictionary = entry_value as Dictionary
        var species_id: String = str(entry.get("species_id", species_key))
        var family_id: String = str(entry.get("family_id", species_id))
        if species_id.is_empty() or family_id.is_empty():
            continue

        var family_catch_rate: float = maxf(
            0.0001,
            float(entry.get("family_catch_rate", entry.get("catch_rate", 1.0)))
        )

        # Never rewrite an established older mapping. The Gen-2 shards only
        # supplement families/species that the legacy encounter file did not know.
        if not _encounter_species_to_family.has(species_id):
            _encounter_species_to_family[species_id] = family_id

        if not _encounter_families.has(family_id):
            _encounter_families[family_id] = {
                "family_catch_rate": family_catch_rate
            }


func _merge_gen3_encounter_family_data(data_path: String) -> void:
    var file := FileAccess.open(data_path, FileAccess.READ)
    if file == null:
        push_warning("Gen-3-Begegnungsdaten fehlen: " + data_path)
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_warning("Gen-3-Begegnungsdaten sind ungültig: " + data_path)
        return

    var species_value: Variant = (parsed as Dictionary).get("species", {})
    if not (species_value is Dictionary):
        push_warning("Gen-3-Begegnungsdaten enthalten keine Species: " + data_path)
        return

    for species_key: Variant in (species_value as Dictionary).keys():
        var entry_value: Variant = (species_value as Dictionary).get(species_key, {})
        if not (entry_value is Dictionary):
            continue

        var entry: Dictionary = entry_value as Dictionary
        var species_id: String = str(entry.get("species_id", species_key))
        var family_id: String = str(entry.get("family_id", species_id))
        if species_id.is_empty() or family_id.is_empty():
            continue

        var family_catch_rate: float = maxf(
            0.0001,
            float(entry.get("family_catch_rate", entry.get("catch_rate", 1.0)))
        )

        # Never rewrite an established older mapping. The Gen-3 shards only
        # supplement families/species that the legacy encounter file did not know.
        if not _encounter_species_to_family.has(species_id):
            _encounter_species_to_family[species_id] = family_id

        if not _encounter_families.has(family_id):
            _encounter_families[family_id] = {
                "family_catch_rate": family_catch_rate
            }


func _polish_capture_action_buttons() -> void:
    super._polish_capture_action_buttons()

    if capture_actions == null or pending_capture.is_empty():
        return

    var capture_name: String = str(pending_capture.get("name", "Pokemon"))
    for child: Node in capture_actions.get_children():
        if not (child is Button):
            continue

        var button := child as Button
        if button.text != "ALS REISEGEFÄHRTEN AUFNEHMEN":
            continue

        button.text = (
            "➕  ALS REISEGEFÄHRTEN AUFNEHMEN\n"
            + "%s schließt sich dir an" % capture_name
        )
        _style_route_decision_button(button, true)
