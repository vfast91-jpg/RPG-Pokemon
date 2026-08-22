class_name StartAggroRules
extends RefCounted

const CONFIG_PATH: String = "res://data/rules/start_aggro.json"
const FALLBACK_BASE_AGGRO: float = 10.0
const FALLBACK_LEVEL_WEIGHT: float = 2.0
const FALLBACK_SPECIES_WEIGHT: float = 0.05
const FALLBACK_STAT_KEYS: Array[String] = ["hp", "attack", "defense", "special", "speed"]


static func calculate(species: Dictionary, level: int) -> float:
    var config: Dictionary = _load_config()
    var base_aggro: float = float(config.get("base_aggro", FALLBACK_BASE_AGGRO))
    var level_weight: float = float(config.get("level_weight", FALLBACK_LEVEL_WEIGHT))
    var species_weight: float = float(config.get("species_base_stat_weight", FALLBACK_SPECIES_WEIGHT))
    return (
        base_aggro
        + float(maxi(1, level)) * level_weight
        + float(base_stat_total(species, config)) * species_weight
    )


static func base_stat_total(species: Dictionary, config: Dictionary = {}) -> int:
    var base_stats_value: Variant = species.get("base_stats", {})
    if not (base_stats_value is Dictionary):
        return 0
    var base_stats: Dictionary = base_stats_value

    var keys: Array[String] = FALLBACK_STAT_KEYS
    var configured_keys: Variant = config.get("base_stat_keys", [])
    if configured_keys is Array and not (configured_keys as Array).is_empty():
        keys = []
        for key_value: Variant in configured_keys:
            keys.append(str(key_value))

    var total: int = 0
    for key: String in keys:
        total += maxi(0, int(base_stats.get(key, 0)))
    return total


static func _load_config() -> Dictionary:
    if not FileAccess.file_exists(CONFIG_PATH):
        return {}
    var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
