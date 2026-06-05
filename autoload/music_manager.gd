extends Node

const SOUNDS_DIR := "res://sounds/"

var _player: AudioStreamPlayer
var _playlist: Array[String] = []
var _play_index: int = 0


func _ready() -> void:
	_ensure_music_bus()
	_build_playlist()
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.finished.connect(_on_track_finished)
	add_child(_player)
	_apply_music_state()


func set_music_volume(linear: float) -> void:
	GameSettings.music_volume = clampf(linear, 0.0, 1.0)
	GameSettings.save_settings()
	_apply_music_state()


func get_music_volume() -> float:
	return GameSettings.music_volume


func set_music_enabled(enabled: bool) -> void:
	GameSettings.music_enabled = enabled
	GameSettings.save_settings()
	_apply_music_state()


func get_music_enabled() -> bool:
	return GameSettings.music_enabled


func ensure_playing() -> void:
	if _player == null or !GameSettings.music_enabled:
		return
	if !_player.playing and !_playlist.is_empty():
		_play_current()


func _apply_music_state() -> void:
	if !GameSettings.music_enabled:
		if _player != null:
			_player.stop()
		var bus_index: int = AudioServer.get_bus_index("Music")
		if bus_index >= 0:
			AudioServer.set_bus_mute(bus_index, true)
		return
	_apply_volume_from_settings()
	ensure_playing()


func _ensure_music_bus() -> void:
	var bus_index: int = AudioServer.get_bus_index("Music")
	if bus_index < 0:
		bus_index = AudioServer.bus_count
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, "Music")


func _apply_volume_from_settings() -> void:
	var bus_index: int = AudioServer.get_bus_index("Music")
	if bus_index < 0:
		return
	var linear: float = GameSettings.music_volume
	var db: float = linear_to_db(maxf(linear, 0.0001)) if linear > 0.0 else -80.0
	AudioServer.set_bus_volume_db(bus_index, db)
	AudioServer.set_bus_mute(bus_index, linear <= 0.0)


func _build_playlist() -> void:
	_playlist.clear()
	var dir := DirAccess.open(SOUNDS_DIR)
	if dir == null:
		push_warning("MusicManager: cannot open %s" % SOUNDS_DIR)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if !dir.current_is_dir() and file_name.ends_with(".wav"):
			_playlist.append(SOUNDS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	_shuffle_playlist()


func _shuffle_playlist() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(_playlist.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = _playlist[i]
		_playlist[i] = _playlist[j]
		_playlist[j] = tmp
	_play_index = 0


func _play_current() -> void:
	if _playlist.is_empty():
		return
	var stream: AudioStream = load(_playlist[_play_index])
	if stream == null:
		_skip_to_next_track()
		return
	_player.stream = stream
	_player.play()


func _skip_to_next_track() -> void:
	_play_index += 1
	if _play_index >= _playlist.size():
		_shuffle_playlist()
	if !_playlist.is_empty():
		_play_current()


func _advance_and_play() -> void:
	_skip_to_next_track()


func _on_track_finished() -> void:
	_advance_and_play()
