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
const STINGER_LEVEL_UP: String = "res://assets/audio/music/stingers/50. Level Up!.mp3"
const STINGER_ITEM: String = "res://assets/audio/music/stingers/18. Obtained an Item!.mp3"
const STINGER_EVOLUTION: String = "res://assets/audio/music/stingers/63. Congratulations! Your Pokémon Evolved!.mp3"
const STINGER_POKEMON: String = "res://assets/audio/music/stingers/201. Obtained a Pokémon! [Unused].mp3"

const SFX_ATTACK: String = "res://assets/audio/sfx/freesound_community-whoosh-6316.mp3"

# Global rule for every long music track:
# - skip the first 3 seconds
# - skip the final 5 seconds (usually fade-out)
# - restart immediately at second 3
# Manual looping is used because Godot's native MP3 loop offset can choose the
# restart position, but does not provide the required early loop end point.
const LOOP_START_SECONDS: float = 3.0
const LOOP_END_SKIP_SECONDS: float = 5.0

const MUSIC_VOLUME_DB: float = -9.0
const EVENT_VOLUME_DB: float = -4.0
const SFX_VOLUME_DB: float = -5.0
const SFX_POOL_SIZE: int = 4

var current_battle_kind: String = "normal"
var _prepared_battle_kind: String = "normal"
var _current_music_path: String = ""
var _music_manual_loop_active: bool = false
var _music_loop_end_seconds: float = 0.0

var _music_player: AudioStreamPlayer
var _event_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0


func _ready() -> void:
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.volume_db = MUSIC_VOLUME_DB
    add_child(_music_player)

    _event_player = AudioStreamPlayer.new()
    _event_player.name = "EventPlayer"
    _event_player.volume_db = EVENT_VOLUME_DB
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
    _event_player.stop()

    match current_battle_kind:
        "final":
            _play_looping_music(TRACK_BATTLE_FINAL)
        "boss":
            _play_looping_music(TRACK_BATTLE_BOSS)
        _:
            _play_looping_music(TRACK_BATTLE_NORMAL)


func play_victory(kind: String = "normal") -> void:
    _event_player.stop()
    var path: String = STINGER_VICTORY_BOSS if _normalized_battle_kind(kind) in ["boss", "final"] else STINGER_VICTORY_NORMAL
    _play_one_shot_on_music_channel(path)


func play_level_up() -> void:
    _play_event(STINGER_LEVEL_UP)


func play_item_obtained() -> void:
    _play_event(STINGER_ITEM)


func play_evolution_success() -> void:
    _play_event(STINGER_EVOLUTION)


func play_pokemon_obtained() -> void:
    _play_event(STINGER_POKEMON)


func play_attack_sfx() -> void:
    if _sfx_players.is_empty():
        return
    var stream: AudioStream = _load_audio(SFX_ATTACK)
    if stream == null:
        return

    var player: AudioStreamPlayer = _sfx_players[_next_sfx_player]
    _next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
    player.stop()
    player.stream = stream
    player.play()


func stop_music() -> void:
    _music_manual_loop_active = false
    _music_loop_end_seconds = 0.0
    if _music_player != null:
        _music_player.stop()
    _current_music_path = ""


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

    _music_player.stop()
    _music_player.stream = stream
    _music_player.volume_db = MUSIC_VOLUME_DB
    _music_manual_loop_active = loop_end > LOOP_START_SECONDS
    _music_loop_end_seconds = loop_end
    _current_music_path = path
    _music_player.play(LOOP_START_SECONDS if stream_length > LOOP_START_SECONDS else 0.0)


func _play_one_shot_on_music_channel(path: String) -> void:
    if _music_player == null:
        return
    var stream: AudioStream = _load_audio(path)
    if stream == null:
        return
    _disable_loop(stream)
    _music_manual_loop_active = false
    _music_loop_end_seconds = 0.0
    _music_player.stop()
    _music_player.stream = stream
    _music_player.volume_db = MUSIC_VOLUME_DB
    _music_player.play()
    _current_music_path = path


func _play_event(path: String) -> void:
    if _event_player == null:
        return
    var stream: AudioStream = _load_audio(path)
    if stream == null:
        return
    _disable_loop(stream)
    _event_player.stop()
    _event_player.stream = stream
    _event_player.volume_db = EVENT_VOLUME_DB
    _event_player.play()


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
