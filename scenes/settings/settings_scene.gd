extends Control

signal back_requested

@onready var music_check: CheckBox = %MusicCheck
@onready var volume_slider: HSlider = %VolumeSlider


func _ready() -> void:
	music_check.button_pressed = MusicManager.get_music_enabled()
	volume_slider.value = MusicManager.get_music_volume()
	_sync_volume_controls()
	music_check.toggled.connect(_on_music_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)


func _on_music_toggled(enabled: bool) -> void:
	MusicManager.set_music_enabled(enabled)
	_sync_volume_controls()


func _on_volume_changed(value: float) -> void:
	MusicManager.set_music_volume(value)


func _sync_volume_controls() -> void:
	var enabled: bool = music_check.button_pressed
	volume_slider.editable = enabled
	volume_slider.modulate.a = 1.0 if enabled else 0.45


func _on_back_pressed() -> void:
	back_requested.emit()
