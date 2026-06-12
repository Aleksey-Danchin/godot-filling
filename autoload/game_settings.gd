extends Node

const SETTINGS_PATH := "user://settings.cfg"
const KEY_MUSIC_VOLUME := "music_volume"
const KEY_MUSIC_ENABLED := "music_enabled"

var music_volume: float = 0.7
var music_enabled: bool = true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SETTINGS_PATH)
	if err != OK:
		return
	music_volume = clampf(float(config.get_value("audio", KEY_MUSIC_VOLUME, music_volume)), 0.0, 1.0)
	music_enabled = bool(config.get_value("audio", KEY_MUSIC_ENABLED, music_enabled))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", KEY_MUSIC_VOLUME, music_volume)
	config.set_value("audio", KEY_MUSIC_ENABLED, music_enabled)
	config.save(SETTINGS_PATH)
