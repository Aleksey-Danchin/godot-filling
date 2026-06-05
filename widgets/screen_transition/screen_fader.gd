extends CanvasLayer

const FADE_STANDARD_SEC := 0.45
const FADE_MENU_TO_GAME_SEC := 0.55
const FADE_REVEAL_SEC := 0.45

var _overlay: ColorRect = null
var _play_board_intro_after_fade: bool = false
var _is_fading: bool = false
var _awaiting_reveal: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	if !get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)


func _build_overlay() -> void:
	if _overlay != null:
		return

	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.offset_right = 0.0
	_overlay.offset_bottom = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.BLACK
	_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_overlay)


func fade_out(duration_sec: float) -> void:
	_build_overlay()
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_is_fading = true
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, maxf(duration_sec, 0.01))
	await tween.finished
	_is_fading = false


func fade_in(duration_sec: float) -> void:
	_build_overlay()
	_overlay.visible = true
	_overlay.modulate.a = 1.0
	_is_fading = true
	_awaiting_reveal = false
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, maxf(duration_sec, 0.01))
	await tween.finished
	_overlay.visible = false
	_is_fading = false


func fade_in_tween(duration_sec: float) -> Tween:
	_build_overlay()
	_overlay.visible = true
	_overlay.modulate.a = 1.0
	_is_fading = true
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, maxf(duration_sec, 0.01))
	tween.finished.connect(_on_fade_in_tween_finished)
	return tween


func _on_fade_in_tween_finished() -> void:
	_overlay.visible = false
	_is_fading = false
	_awaiting_reveal = false


func transition_to_scene(scene_path: String, duration_sec: float, reveal_after_load: bool = true) -> void:
	await fade_out(duration_sec)
	_overlay.modulate.a = 1.0
	_overlay.visible = true
	_awaiting_reveal = reveal_after_load
	get_tree().change_scene_to_file(scene_path)
	if !reveal_after_load:
		await fade_in(duration_sec)


func transition_menu_to_game(scene_path: String) -> void:
	_play_board_intro_after_fade = true
	await transition_to_scene(scene_path, FADE_MENU_TO_GAME_SEC, true)


func transition_standard(scene_path: String) -> void:
	_play_board_intro_after_fade = false
	await transition_to_scene(scene_path, FADE_STANDARD_SEC, true)


func peek_board_intro() -> bool:
	return _play_board_intro_after_fade


func consume_board_intro() -> bool:
	if !_play_board_intro_after_fade:
		return false
	_play_board_intro_after_fade = false
	return true


func is_fading() -> bool:
	return _is_fading


func is_awaiting_reveal() -> bool:
	return _awaiting_reveal


func wait_until_idle() -> void:
	while _is_fading:
		await get_tree().process_frame


func _on_scene_changed() -> void:
	_is_fading = false
	_build_overlay()
	if _awaiting_reveal:
		_overlay.visible = true
		_overlay.modulate.a = 1.0
	else:
		_hide_overlay()


func _hide_overlay() -> void:
	_build_overlay()
	_overlay.modulate.a = 0.0
	_overlay.visible = false
