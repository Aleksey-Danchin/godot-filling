extends Control

signal back_requested

@onready var music_check: CheckBox = %MusicCheck
@onready var volume_slider: HSlider = %VolumeSlider
@onready var progress_horizontal: Button = %ProgressHorizontal
@onready var progress_vertical: Button = %ProgressVertical

var _progress_group: ButtonGroup = null


func _ready() -> void:
	_progress_group = ButtonGroup.new()
	progress_horizontal.button_group = _progress_group
	progress_vertical.button_group = _progress_group
	music_check.button_pressed = MusicManager.get_music_enabled()
	volume_slider.value = MusicManager.get_music_volume()
	_sync_volume_controls()
	_sync_progress_orientation_buttons()
	music_check.toggled.connect(_on_music_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)


func _on_music_toggled(enabled: bool) -> void:
	MusicManager.set_music_enabled(enabled)
	_sync_volume_controls()


func _on_volume_changed(value: float) -> void:
	MusicManager.set_music_volume(value)


func _on_progress_horizontal_toggled(pressed: bool) -> void:
	if !pressed:
		_sync_progress_orientation_buttons()
		return
	GameSettings.set_turns_progress_orientation("horizontal")
	_sync_progress_orientation_buttons()


func _on_progress_vertical_toggled(pressed: bool) -> void:
	if !pressed:
		_sync_progress_orientation_buttons()
		return
	GameSettings.set_turns_progress_orientation("vertical")
	_sync_progress_orientation_buttons()


func _sync_volume_controls() -> void:
	var enabled: bool = music_check.button_pressed
	volume_slider.editable = enabled
	volume_slider.modulate.a = 1.0 if enabled else 0.45


func _sync_progress_orientation_buttons() -> void:
	var orientation: String = GameSettings.turns_progress_orientation
	progress_horizontal.set_pressed_no_signal(orientation == "horizontal")
	progress_vertical.set_pressed_no_signal(orientation == "vertical")


func _on_back_pressed() -> void:
	back_requested.emit()
