extends Node

## Autoload. Owns the generated sound library and a small pool of players.

const VOICES := 10

var _sounds: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music_player: AudioStreamPlayer
var _music_stream: AudioStreamWAV

var sfx_enabled := true
var music_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sounds = Sfx.library()

	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voices.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.volume_db = -7.0
	add_child(_music_player)


func play(key: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not sfx_enabled or not _sounds.has(key):
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = _sounds[key]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Slight random detune keeps repeated sounds from turning into a machine gun.
func play_varied(key: String, spread: float = 0.06) -> void:
	play(key, randf_range(1.0 - spread, 1.0 + spread))


func start_music() -> void:
	if not music_enabled:
		return
	if _music_stream == null:
		_music_stream = Sfx.music()
	if _music_player.playing:
		return
	_music_player.stream = _music_stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if on:
		start_music()
	else:
		stop_music()


func set_sfx_enabled(on: bool) -> void:
	sfx_enabled = on
