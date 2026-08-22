extends SceneTree
const DATA_PATH: String = "res://data/gen1_species_encounter_families_v1.json"
const EXPECTED_FAMILY_COUNT: int = 16
const EXPECTED_SPECIES_COUNT: int = 43
var failures: int = 0
func _initialize() -> void:
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    _check(file != null, "Familien-Begegnungsdaten fehlen: %s" % DATA_PATH)
    if file == null:
        _finish()
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    _check(parsed is Dictionary, "Familien-Begegnungsdaten sind kein gültiges Dictionary.")
    if not (parsed is Dictionary):
        _finish()
        return
    var pack: Dictionary = parsed
    _check(int(pack.get("schema_version", 0)) == 1, "schema_version muss 1 sein.")
    var families_value: Variant = pack.get("families", {})
    var mapping_value: Variant = pack.get("species_to_family", {})
    _check(families_value is Dictionary, "families muss ein Dictionary sein.")
    _check(mapping_value is Dictionary, "species_to_family muss ein Dictionary sein.")
    if not (families_value is Dictionary) or not (mapping_value is Dictionary):
        _finish()
        return
    var families: Dictionary = families_value
    var mapping: Dictionary = mapping_value
    _check(families.size() == EXPECTED_FAMILY_COUNT, "Es werden %d Familien erwartet, gefunden: %d." % [EXPECTED_FAMILY_COUNT, families.size()])
    _check(mapping.size() == EXPECTED_SPECIES_COUNT, "Es werden %d Spezies-Zuordnungen erwartet, gefunden: %d." % [EXPECTED_SPECIES_COUNT, mapping.size()])
    _check_close(_family_rate(families, "bulbasaur"), 45.0, 0.000001, "Bisasam-Familien-Fangrate")
    _check_close(_family_rate(families, "caterpie"), 140.0, 0.000001, "Raupy-Familien-Fangrate")
    _check_close(_family_rate(families, "rattata"), 191.0, 0.000001, "Rattfratz-Familien-Fangrate")
    _check_close(_family_rate(families, "pichu"), 151.666667, 0.00001, "Pichu/Pikachu/Raichu-Familien-Fangrate")
    _check_close(_family_rate(families, "sandshrew"), 172.5, 0.000001, "Sandan/Sandamer-Familien-Fangrate")
    _check_close(_family_rate(families, "nidoran_f"), 133.33333333333334, 0.00001, "Nidoran♀-Familien-Fangrate")
    _check_close(_family_rate(families, "vulpix"), 132.5, 0.000001, "Vulpix/Vulnona-Familien-Fangrate")
    _check_close(_family_rate(families, "igglybuff"), 130.0, 0.000001, "Fluffeluff/Pummeluff/Knuddeluff-Familien-Fangrate")
    for family_id_value: Variant in families.keys():
        var family_id: String = str(family_id_value)
        var family_value: Variant = families.get(family_id, {})
        _check(family_value is Dictionary, "Familie %s ist kein Dictionary." % family_id)
        if not (family_value is Dictionary):
            continue
        var family: Dictionary = family_value
        var members_value: Variant = family.get("members", [])
        _check(members_value is Array, "Familie %s braucht ein members-Array." % family_id)
        _check(float(family.get("family_catch_rate", 0.0)) > 0.0, "Familie %s braucht eine positive Familien-Fangrate." % family_id)
        if not (members_value is Array):
            continue
        var members: Array = members_value
        _check(not members.is_empty(), "Familie %s darf nicht leer sein." % family_id)
        for species_id_value: Variant in members:
            var species_id: String = str(species_id_value)
            _check(mapping.has(species_id), "Spezies %s aus Familie %s fehlt in species_to_family." % [species_id, family_id])
            _check(str(mapping.get(species_id, "")) == family_id, "Spezies %s muss auf Familie %s zeigen." % [species_id, family_id])
    for species_id_value: Variant in mapping.keys():
        var species_id: String = str(species_id_value)
        var family_id: String = str(mapping.get(species_id, ""))
        _check(families.has(family_id), "Spezies %s zeigt auf unbekannte Familie %s." % [species_id, family_id])
        if not families.has(family_id):
            continue
        var family_value: Variant = families.get(family_id, {})
        if family_value is Dictionary:
            var members_value: Variant = (family_value as Dictionary).get("members", [])
            if members_value is Array:
                _check((members_value as Array).has(species_id), "Spezies %s fehlt in der Mitgliederliste ihrer Familie %s." % [species_id, family_id])
    _finish()
func _family_rate(families: Dictionary, family_id: String) -> float:
    var family_value: Variant = families.get(family_id, {})
    if not (family_value is Dictionary):
        _check(false, "Familie %s fehlt." % family_id)
        return 0.0
    return float((family_value as Dictionary).get("family_catch_rate", 0.0))
func _check_close(actual: float, expected: float, tolerance: float, label: String) -> void:
    _check(absf(actual - expected) <= tolerance, "%s: erwartet %.6f, erhalten %.6f." % [label, expected, actual])
func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error(message)
func _finish() -> void:
    if failures == 0:
        print("Route encounter family data test: PASS")
        quit(0)
    else:
        push_error("Route encounter family data test: %d Fehler" % failures)
        quit(1)