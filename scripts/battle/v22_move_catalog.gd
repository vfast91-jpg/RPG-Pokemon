extends RefCounted
class_name V22MoveCatalog

# Canonical move IDs from Attacken-Datenbank V22 (2026-08-23).
# This list is the runtime completeness gate for the final composed battle stack.
const IDS: Array[String] = [
    "tackle", "scratch", "growl", "tail_whip", "vine_whip", "growth", "leech_seed", "ember",
    "smokescreen", "water_gun", "withdraw", "rapid_spin", "string_shot", "bug_bite", "poison_sting", "sand_attack",
    "gust", "quick_attack", "focus_energy", "bite", "peck", "leer", "assurance", "wrap",
    "thunder_shock", "play_nice", "sweet_kiss", "razor_leaf", "poison_powder", "sleep_powder", "take_down", "protect",
    "seed_bomb", "sweet_scent", "petal_blizzard", "synthesis", "worry_seed", "power_whip", "solar_beam", "petal_dance",
    "dragon_breath", "scary_face", "fire_fang", "slash", "flamethrower", "dragon_claw", "heat_wave", "air_slash",
    "fire_spin", "inferno", "flare_blitz", "water_pulse", "rain_dance", "aqua_tail", "shell_smash", "flash_cannon",
    "iron_defense", "hydro_pump", "wave_crash", "harden", "electroweb", "supersonic", "confusion", "stun_spore",
    "psybeam", "whirlwind", "safeguard", "bug_buzz", "tailwind", "rage_powder", "quiver_dance", "hyper_beam",
    "giga_impact", "fury_attack", "fury_cutter", "laser_focus", "venoshock", "toxic_spikes", "pin_missile", "poison_jab",
    "agility", "endeavor", "fell_stinger", "sunny_day", "work_up", "twister", "feather_dance", "hurricane",
    "wing_attack", "roost", "aerial_ace", "swords_dance", "crunch", "sucker_punch", "super_fang", "double_edge",
    "roar", "pluck", "drill_run", "drill_peck", "ice_fang", "thunder_fang", "stockpile", "swallow",
    "spit_up", "acid_spray", "sludge_bomb", "gastro_acid", "belch", "haze", "coil", "gunk_shot",
    "mud_slap", "nuzzle", "charm", "feint", "spark", "iron_tail", "fake_tears", "thunder_punch",
    "discharge", "double_team", "electro_ball", "light_screen", "nasty_plot", "thunder", "thunder_wave", "thunderbolt",
    "glare", "screech", "acid", "trailblaze", "magical_leaf", "bullet_seed", "giga_drain", "energy_ball",
    "facade", "endure", "rest", "sleep_talk", "substitute", "grass_knot", "helping_hand", "grassy_terrain",
    "grass_pledge", "false_swipe", "body_slam", "leaf_storm", "toxic", "knock_off", "weather_ball", "grassy_glide",
    "curse", "bulldoze", "stomping_tantrum", "amnesia", "earth_power", "earthquake", "frenzy_plant", "metal_claw",
    "swift", "rock_tomb", "flame_charge", "fling", "dragon_tail", "dig", "brick_break", "shadow_claw",
    "fire_punch", "rock_slide", "dragon_dance", "will_o_wisp", "dragon_pulse", "fire_blast", "fire_pledge", "outrage",
    "overheat", "focus_blast", "focus_punch", "temper_flare", "breaking_swipe", "acrobatics", "air_cutter", "sandstorm",
    "fly", "blast_burn", "heat_crash", "scorching_sands", "dragon_cheer", "chilling_water", "icy_wind", "mud_shot",
    "zen_headbutt", "ice_punch", "liquidation", "surf", "ice_spinner", "ice_beam", "blizzard", "water_pledge",
    "gyro_ball", "flip_turn", "whirlpool", "muddy_water", "avalanche", "body_press", "dark_pulse", "aura_sphere",
    "hydro_cannon", "smack_down", "thief", "snore", "attract", "u_turn", "echoed_voice", "draining_kiss",
    "psychic", "baton_pass", "shadow_ball", "skill_swap", "pollen_puff", "payback", "flash", "x_scissor",
    "swagger", "cut", "defog", "rock_smash", "steel_wing", "taunt", "shock_wave", "charge_beam",
    "strength", "poison_tail", "snarl", "psychic_fangs", "leech_life", "spite", "lash_out", "scale_shot",
    "sludge_wave", "skitter_smack", "pain_split", "throat_chop", "disarming_voice", "volt_switch", "reflect", "encore",
    "play_rough", "reversal", "electric_terrain", "wild_charge", "charge", "eerie_impulse", "alluring_voice", "upper_hand",
    "defense_curl", "rollout", "crush_claw", "fury_swipes", "sand_tomb", "low_kick", "spikes", "stealth_rock",
    "stone_edge", "high_horsepower", "double_kick", "flatter", "superpower", "drain_punch", "megahorn", "horn_attack",
    "iron_head", "splash", "pound", "copycat", "sing", "stored_power", "after_you", "life_dew",
    "metronome", "moonlight", "gravity", "meteor_mash", "follow_me", "cosmic_power", "moonblast", "psyshock",
    "dazzling_gleam", "trick", "hyper_voice", "calm_mind", "misty_terrain", "uproar", "imprison", "dual_wingbeat",
    "misty_explosion", "psych_up", "meteor_beam", "future_sight", "night_shade", "disable", "incinerate", "confuse_ray",
    "extrasensory", "hex", "foul_play", "burning_jealousy", "covet", "round", "mimic", "expanding_force",
    "psychic_noise", "absorb", "brave_bird", "double_hit", "hypnosis", "night_slash", "ominous_wind", "poison_fang",
    "razor_wind", "sky_attack", "mega_drain", "solar_blade", "aromatherapy", "cross_poison", "spore", "lunge",
    "pounce", "struggle_bug", "astonish", "fissure", "rock_blast", "tri_attack", "fake_out", "pay_day",
    "power_gem", "switcheroo", "aqua_jet", "low_sweep", "soak", "vacuum_wave", "waterfall", "wonder_room",
    "bulk_up", "close_combat", "cross_chop", "rage_fist", "seismic_toss", "thrash", "extreme_speed", "flame_wheel",
    "howl", "retaliate", "belly_drum", "bounce", "bubble_beam", "circle_throw", "coaching", "dynamic_punch",
    "perish_song", "teleport", "psycho_cut", "recover", "dream_eater", "power_up_punch", "vital_throw", "bullet_punch",
    "detect", "heavy_slam", "dual_chop", "storm_throw", "leaf_blade", "reflect_type", "acid_armor", "rock_polish",
    "rock_throw", "self_destruct", "explosion", "hard_press", "stomp", "smart_strike", "mystical_fire", "ally_switch",
    "yawn", "headbutt", "slack_off", "psychic_terrain", "scald", "snowscape", "trick_room", "chilly_reception",
    "heal_pulse", "magnet_rise", "steel_beam", "metal_sound", "magnetic_flux", "mirror_coat", "lock_on", "zap_cannon",
    "supercell_slam", "revenge", "brutal_swing", "acupressure", "aqua_ring", "aurora_beam", "brine", "dive",
    "ice_shard", "icicle_spear", "sheer_cold", "triple_axel", "poison_gas", "sludge", "minimize", "memento",
    "razor_shell", "icicle_crash", "lick", "mean_look", "shadow_punch", "destiny_bond", "poltergeist", "phantom_force",
    "ancient_power", "head_smash", "hammer_arm", "wide_guard", "flail", "slam", "crabhammer", "guillotine",
    "hail", "counter", "final_gambit", "wood_hammer", "bonemerang", "skull_bash", "blaze_kick", "mega_kick",
    "high_jump_kick", "axe_kick", "mega_punch", "quick_guard", "triple_kick", "rock_climb", "smog", "clear_smog",
    "horn_drill", "rock_wrecker", "soft_boiled", "last_resort", "healing_wish", "bind", "block", "tickle",
    "ingrain", "heal_block", "torment", "magnet_bomb", "silver_wind", "stone_axe", "powder_snow", "lovely_kiss",
    "recycle", "lava_plume", "mountain_gale", "raging_bull", "mist", "transform", "wish", "morning_sun",
    "guard_split", "freeze_dry", "conversion", "conversion_2", "dragon_rush", "draco_meteor", "psystrike"
]


static func contains(move_id: String) -> bool:
    return IDS.has(move_id)


static func count() -> int:
    return IDS.size()
