extends Node

# Central audio controller for Pokemon Timeflow.
# Gameplay scripts only announce context changes/events; file paths, volumes and
# loop configuration stay in one place.

const TRACK_MAIN_MENU: String = "res://assets/audio/music/loops/45. Pokémon Gym.mp3"
const TRACK_ROUTE_EARLY: String = "res://assets/audio/music/loops/94. Fight Area (Day).mp3"
const TRACK_ROUTE_MID: String = "res://assets/audio/music/loops/78. Team Galactic HQ.mp3"
const TRACK_ROUTE_LATE: String = "res://assets/audio/music/loops/91. Victory Road.mp3"
const TRACK_ROUTE_ENDGAME: String = "res://assets/audio/music/loops/82. Spear Pillar.mp3"
const TRACK_BATTLE_NORMAL: String = "res://assets/audio/music/loops/15. Battle! (Wild Pokémon).mp3"
const TRACK_BATTLE_BOSS: String = "res://assets/audio/music/loops/46. Battle! (Gym Leader).mp3"
const TRACK_BATTLE_FINAL: String = "res://assets/audio/music/loops/168. Battle! (Champion).mp3"

const STINGER_VICTORY_NORMAL: String = "res://assets/audio/music/stingers/16. Victory! (Wild Pokémon).mp3"
const STINGER_VICTORY_BOSS: String = "res://assets/audio/music/stingers/47. Victory! (Gym Leader).mp3"
const STINGER_DEFEAT: String = "res://assets/audio/music/stingers/1-38. Lose.mp3"
const STINGER_LEVEL_UP: String = "res://assets/audio/music/stingers/50. Level Up!.mp3"
const STINGER_ITEM: String = "res://assets/audio/music/stingers/18. Obtained an Item!.mp3"
const STINGER_EVOLUTION: String = "res://assets/audio/music/stingers/63. Congratulations! Your Pokémon Evolved!.mp3"
const STINGER_POKEMON: String = "res://assets/audio/music/stingers/201. Obtained a Pokémon! [Unused].mp3"

const SFX_ATTACK: String = "res://assets/audio/sfx/freesound_community-whoosh-6316.mp3"
const SFX_FAINT: String = "res://assets/audio/sfx/freesound_community-retro-video-game-death-95730.mp3"
const SFX_HEAL: String = "res://assets/audio/sfx/yodguard-healing-magic-6-378666.mp3"

# One central reduction for the complete game mix. Individual channel values
# below keep their relative balance; this only lowers Pokemon Timeflow as a whole.
const MASTER_VOLUME_DB: float = -5.0

# Global rule for every long music track:
# - first playback starts at 0:00 so the musical intro is heard once
# - five seconds before the file ends, jump to second 3
# - every later loop therefore runs from second 3 to five seconds before the end
# Manual looping is used because Godot's native MP3 loop offset can choose the
# restart position, but does not provide the required early loop end point.
const LOOP_START_SECONDS: float = 3.0
const LOOP_END_SKIP_SECONDS: float = 5.0

# Music changes use two players so the outgoing and incoming tracks overlap
# briefly instead of producing a hard cut.
const MUSIC_CROSSFADE_SECONDS: float = 0.65
const MUSIC_FADE_FLOOR_DB: float = -48.0
const MUSIC_VOLUME_DB: float = -9.0

# Short reward/event jingles should sit clearly in front of the route music.
# Instead of letting both compete at full volume, the active music is briefly
# ducked and returns smoothly after the event has finished.
const EVENT_MUSIC_DUCK_DB: float = -22.0
const EVENT_DUCK_SECONDS: float = 0.18
const EVENT_RELEASE_SECONDS: float = 0.35
const EVENT_VOLUME_DB: float = -4.0
const SFX_VOLUME_DB: float = -5.0
const SFX_FAINT_VOLUME_DB: float = -11.0
const SFX_HEAL_VOLUME_DB: float = -10.0
const SFX_POOL_SIZE: int = 4

var current_battle_kind: String = "normal"
var _prepared_battle_kind: String = "normal"
var _current_music_path: String = ""
var _music_manual_loop_active: bool = false
var _music_loop_end_seconds: float = 0.0

var _music_player: AudioStreamPlayer
var _music_standby_player: AudioStreamPlayer
var _music_transition_tween: Tween
var _event_player: AudioStreamPlayer
var _event_duck_tween: Tween
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0


func _ready() -> void:
    var master_bus: int = AudioServer.get_bus_index("Master")
    if master_bus >= 0:
        AudioServer.set_bus_volume_db(master_bus, MASTER_VOLUME_DB)

    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayerA"
    _music_player.volume_db = MUSIC_VOLUME_DB
    add_child(_music_player)

    _music_standby_player = AudioStreamPlayer.new()
    _music_standby_player.name = "MusicPlayerB"
    _music_standby_player.volume_db = MUSIC_VOLUME_DB
    add_child(_music_standby_player)

    _event_player = AudioStreamPlayer.new()
    _event_player.name = "EventPlayer"
    _event_player.volume_db = EVENT_VOLUME_DB
    _event_player.finished.connect(_on_event_finished)
    add_child(_event_player)

    for index: int in range(SFX_POOL_SIZE):
        var player := AudioStreamPlayer.new()
        player.name = "SFXPlayer%d" % (index + 1)
        player.volume_db = SFX_VOLUME_DB
        add_child(player)
        _sfx_players.append(player)


func _process(_delta: float) -> void:
    if not _music_manual_loop_active or _music_player == null or not _music_player.playing:
        return
    if _music_loop_end_seconds <= LOOP_START_SECONDS:
        return

    # The first pass starts at 0:00. Only when the loop boundary is reached do
    # we jump back to second 3, so the intro is never repeated afterwards.
    if _music_player.get_playback_position() >= _music_loop_end_seconds:
        _music_player.play(LOOP_START_SECONDS)


func play_main_menu() -> void:
    _play_looping_music(TRACK_MAIN_MENU)


func play_route(stage: int) -> void:
    var path: String = TRACK_ROUTE_EARLY
    if stage >= 81:
        path = TRACK_ROUTE_ENDGAME
    elif stage >= 61:
        path = TRACK_ROUTE_LATE
    elif stage >= 31:
        path = TRACK_ROUTE_MID
    _play_looping_music(path)


func prepare_battle(kind: String = "normal") -> void:
    _prepared_battle_kind = _normalized_battle_kind(kind)


func play_prepared_battle() -> void:
    current_battle_kind = _prepared_battle_kind
    _prepared_battle_kind = "normal"
    play_battle(current_battle_kind)


func play_battle(kind: String = "normal") -> void:
    current_battle_kind = _normalized_battle_kind(kind)
    _stop_event_for_context_change()

    match current_battle_kind:
        "final":
            _play_looping_music(TRACK_BATTLE_FINAL)
        "boss":
            _play_looping_music(TRACK_BATTLE_BOSS)
        _:
            _play_looping_music(TRACK_BATTLE_NORMAL)


func play_victory(kind: String = "normal") -> void:
    _stop_event_for_context_change()
    var path: String = STINGER_VICTORY_BOSS if _normalized_battle_kind(kind) in ["boss", "final"] else STINGER_VICTORY_NORMAL
    _play_one_shot_on_music_channel(path)


func play_defeat() -> void:
    _stop_event_for_context_change()
    _play_one_shot_on_music_channel(STINGER_DEFEAT)


func play_level_up() -> void:
    _play_event(STINGER_LEVEL_UP)


func play_item_obtained() -> void:
    _play_event(STINGER_ITEM)


func play_evolution_success() -> void:
    _play_event(STINGER_EVOLUTION)


func play_pokemon_obtained() -> void:
    _play_event(STINGER_POKEMON)


func play_attack_sfx() -> void:
    _play_sfx(SFX_ATTACK, SFX_VOLUME_DB)


func play_faint_sfx() -> void:
    _play_sfx(SFX_FAINT, SFX_FAINT_VOLUME_DB)


func play_heal_sfx() -> void:
    _play_sfx(SFX_HEAL, SFX_HEAL_VOLUME_DB)


func _play_sfx(path: String, volume_db: float) -> void:
    if _sfx_players.is_empty():
        return
    var stream: AudioStream = _load_audio(path)
    if stream == null:
        return

    var player: AudioStreamPlayer = _sfx_players[_next_sfx_player]
    _next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
    player.stop()
    player.stream = stream
    player.volume_db = volume_db
    player.play()


func stop_music() -> void:
    _music_manual_loop_active = false
    _music_loop_end_seconds = 0.0
    _current_music_path = ""

    if _music_transition_tween != null:
        _music_transition_tween.kill()
        _music_transition_tween = null
    if _event_duck_tween != null:
        _event_duck_tween.kill()
        _event_duck_tween = null

    if _music_player != null:
        _music_player.stop()
        _music_player.volume_db = MUSIC_VOLUME_DB
    if _music_standby_player != null:
        _music_standby_player.stop()
        _music_standby_player.volume_db = MUSIC_VOLUME_DB


func stop_all() -> void:
    stop_music()
    if _event_player != null:
        _event_player.stop()
    for player: AudioStreamPlayer in _sfx_players:
        player.stop()


func _play_looping_music(path: String) -> void:
    if _music_player == null or path.is_empty():
        return
    if _current_music_path == path and _music_player.playing and _music_manual_loop_active:
        return

    var stream: AudioStream = _load_audio(path)
    if stream == null:
        return
    _disable_loop(stream)

    var stream_length: float = stream.get_length()
    var loop_end: float = stream_length - LOOP_END_SKIP_SECONDS
    if stream_length <= LOOP_START_SECONDS + LOOP_END_SKIP_SECONDS:
        push_warning(
            "Audio ist zu kurz für die globale Loop-Regel 3s/5s: " + path
        )
        loop_end = stream_length

    _transition_music_stream(
        path,
        stream,
        loop_end > LOOP_START_SECONDS,
        loop_end
    )


func _play_one_shot_on_music_channel(path: String) -> void:
    if _music_player == null:
        return
    var stream: AudioStream = _load_audio(path)
    if stream == null:
        return
    _disable_loop(stream)
    _transition_music_stream(path, stream, false, 0.0)


func _transition_music_stream(
    path: String,
    stream: AudioStream,
    manual_loop: bool,
    loop_end_seconds: float
) -> void:
    if _music_player == null or _music_standby_player == null:
        return

    # If another music change happened during the previous crossfade, stop that
    # tween and reuse the two current players for the newest request.
    if _music_transition_tween != null:
        _music_transition_tween.kill()
        _music_transition_tween = null

    var outgoing: AudioStreamPlayer = _music_player
    var incoming: AudioStreamPlayer = _music_standby_player
    var has_outgoing: bool = outgoing.playing
    var target_volume_db: float = _music_target_volume_db()

    incoming.stop()
    incoming.stream = stream
    incoming.volume_db = MUSIC_FADE_FLOOR_DB if has_outgoing else target_volume_db

    # Every newly selected track is a genuinely new playback and therefore gets
    # its complete musical intro once. LOOP_START_SECONDS is used only later by
    # _process() when the first loop boundary is reached.
    incoming.play(0.0)

    _music_player = incoming
    _music_standby_player = outgoing
    _music_manual_loop_active = manual_loop
    _music_loop_end_seconds = loop_end_seconds
    _current_music_path = path

    if not has_outgoing:
        incoming.volume_db = target_volume_db
        outgoing.stop()
        outgoing.volume_db = MUSIC_VOLUME_DB
        return

    _music_transition_tween = create_tween()
    _music_transition_tween.set_parallel(true)
    _music_transition_tween.tween_property(
        outgoing,
        "volume_db",
        MUSIC_FADE_FLOOR_DB,
        MUSIC_CROSSFADE_SECONDS
    )
    _music_transition_tween.tween_property(
        incoming,
        "volume_db",
        target_volume_db,
        MUSIC_CROSSFADE_SECONDS
    )
    _music_transition_tween.finished.connect(_finish_music_transition.bind(outgoing))


func _finish_music_transition(outgoing: AudioStreamPlayer) -> void:
    if outgoing != null and outgoing != _music_player:
        outgoing.stop()
        outgoing.volume_db = MUSIC_VOLUME_DB
    _music_transition_tween = null


func _play_event(path: String) -> void:
    if _event_player == null:
        return
    var stream: AudioStream = _load_audio(path)
    if stream == null:
        return
    _disable_loop(stream)

    # A new event supersedes the previous short jingle. Music remains ducked,
    # so even rapid reward sequences do not create two full-volume music layers.
    _event_player.stop()
    _duck_music_for_event()
    _event_player.stream = stream
    _event_player.volume_db = EVENT_VOLUME_DB
    _event_player.play()


func _duck_music_for_event() -> void:
    _settle_music_transition()

    if _event_duck_tween != null:
        _event_duck_tween.kill()
        _event_duck_tween = null
    if _music_player == null or not _music_player.playing:
        return

    _event_duck_tween = create_tween()
    _event_duck_tween.tween_property(
        _music_player,
        "volume_db",
        EVENT_MUSIC_DUCK_DB,
        EVENT_DUCK_SECONDS
    )


func _on_event_finished() -> void:
    _settle_music_transition()

    if _event_duck_tween != null:
        _event_duck_tween.kill()
        _event_duck_tween = null
    if _music_player == null or not _music_player.playing:
        return

    _event_duck_tween = create_tween()
    _event_duck_tween.tween_property(
        _music_player,
        "volume_db",
        MUSIC_VOLUME_DB,
        EVENT_RELEASE_SECONDS
    )


func _stop_event_for_context_change() -> void:
    if _event_player != null:
        _event_player.stop()
    if _event_duck_tween != null:
        _event_duck_tween.kill()
        _event_duck_tween = null
    if _music_player != null and _music_player.playing:
        _music_player.volume_db = MUSIC_VOLUME_DB


func _settle_music_transition() -> void:
    # If an event starts in the middle of a crossfade, keep the newly selected
    # track and remove the outgoing one. Otherwise the event would have to fight
    # two background tracks at once.
    if _music_transition_tween != null:
        _music_transition_tween.kill()
        _music_transition_tween = null
    if _music_standby_player != null and _music_standby_player.playing:
        _music_standby_player.stop()
        _music_standby_player.volume_db = MUSIC_VOLUME_DB


func _music_target_volume_db() -> float:
    if _event_player != null and _event_player.playing:
        return EVENT_MUSIC_DUCK_DB
    return MUSIC_VOLUME_DB


func _load_audio(path: String) -> AudioStream:
    if not ResourceLoader.exists(path):
        push_warning("Audio fehlt: " + path)
        return null
    var value: Variant = load(path)
    if value is AudioStream:
        return value as AudioStream
    push_warning("Datei ist kein AudioStream: " + path)
    return null


func _disable_loop(stream: AudioStream) -> void:
    if stream is AudioStreamMP3:
        (stream as AudioStreamMP3).loop = false
    elif stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = false


func _normalized_battle_kind(kind: String) -> String:
    var lowered: String = kind.to_lower()
    if lowered == "boss" or lowered == "final":
        return lowered
    return "normal"
