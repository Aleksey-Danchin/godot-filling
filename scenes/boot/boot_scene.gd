extends Control

const MAIN_SCENE_PATH := "res://scenes/main/main_scene.tscn"
const HOLD_SEC := 0.15
const FADE_SEC := 0.5

@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var main_host: Control = $MainHost


func _ready() -> void:
	fade_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_ensure_music_playing()
	await get_tree().create_timer(HOLD_SEC).timeout
	_load_main_under_overlay()
	await _fade_out_overlay()


func _ensure_music_playing() -> void:
	if MusicManager.has_method("ensure_playing"):
		MusicManager.ensure_playing()


func _load_main_under_overlay() -> void:
	var main_packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if main_packed == null:
		push_error("BootScene: cannot load main scene")
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		return
	var main_scene: Control = main_packed.instantiate() as Control
	main_host.add_child(main_scene)
	main_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _fade_out_overlay() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, FADE_SEC)
	await tween.finished
	fade_overlay.visible = false
