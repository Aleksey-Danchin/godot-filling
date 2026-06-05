extends Node

const SETTINGS_PATH := "user://settings.cfg"
const KEY_MUSIC_VOLUME := "music_volume"
const KEY_MUSIC_ENABLED := "music_enabled"
const KEY_TURNS_PROGRESS_ORIENTATION := "turns_progress_orientation"

var music_volume: float = 0.7
var music_enabled: bool = true
var turns_progress_orientation: String = "horizontal"


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_PATH)
	if err != OK:
		return
	music_volume = clampf(float(config.get_value("audio", KEY_MUSIC_VOLUME, music_volume)), 0.0, 1.0)
	music_enabled = bool(config.get_value("audio", KEY_MUSIC_ENABLED, music_enabled))
	turns_progress_orientation = _normalize_progress_orientation(
		str(config.get_value("ui", KEY_TURNS_PROGRESS_ORIENTATION, turns_progress_orientation))
	)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", KEY_MUSIC_VOLUME, music_volume)
	config.set_value("audio", KEY_MUSIC_ENABLED, music_enabled)
	config.set_value("ui", KEY_TURNS_PROGRESS_ORIENTATION, turns_progress_orientation)
	config.save(SETTINGS_PATH)


func set_turns_progress_orientation(orientation: String) -> void:
	turns_progress_orientation = _normalize_progress_orientation(orientation)
	save_settings()


func _normalize_progress_orientation(orientation: String) -> String:
	return "vertical" if orientation == "vertical" else "horizontal"
