extends Node2D

enum Phase { IDLE, GAME_OVER }

const MAIN_SCENE_PATH := "res://scenes/main/main_scene.tscn"
const PARALLAX_SCRIPT := preload("res://widgets/background/parallax_background.gd")
const INTRO_FROM_RIGHT_OFFSET := 920.0
const INTRO_STOP_SHORT_OF_TARGET := Vector2(36.0, 0.0)
const INTRO_SLIDE_SEC := 0.85

@onready var board_field: Node2D = $BoardField
@onready var board_field_setup: Node = $BoardFieldSetup
@onready var board_model: Node = $BoardModel
@onready var board_presentation_state: Node = $BoardPresentationState
@onready var game_session_state: Node = $GameSessionState
@onready var board_view: TileMapLayer = $BoardField/BoardView
@onready var cell_fx_layer_manager: Node2D = $BoardField/BoardView/CellFxLayerManager
@onready var board_camera_controller: Node = $BoardCameraController
@onready var input_controller: Node = $InputController
@onready var move_validator: Node = $MoveValidator
@onready var transition_player: Node = $TransitionPlayer
@onready var hud_controller: CanvasLayer = $HUDController
@onready var game_over_ui: CanvasLayer = $GameOverUI
@onready var game_pause_menu: CanvasLayer = $GamePauseMenu

var phase: Phase = Phase.IDLE
var _initial_board_cells: Dictionary = {}
var _move_generation: int = 0
var _board_field_target_position: Vector2 = Vector2.ZERO
var _intro_animating: bool = false


func _ready() -> void:
	_board_field_target_position = board_field.position
	_setup_parallax()

	if board_view.has_signal("cell_clicked"):
		board_view.cell_clicked.connect(_on_cell_selected)
	transition_player.active_waves_changed.connect(_on_active_waves_changed)
	transition_player.wave_playback_finished.connect(_on_wave_playback_finished)
	game_session_state.state_changed.connect(_on_session_state_changed)
	var pause_menu := get_node("GamePauseMenu")
	if pause_menu.has_signal("restart_requested"):
		pause_menu.restart_requested.connect(_on_pause_restart_requested)
	if pause_menu.has_signal("main_menu_requested"):
		pause_menu.main_menu_requested.connect(_on_pause_main_menu_requested)

	_setup_board_for_new_session()
	await _finish_entry_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if !_is_click_release(event) or game_pause_menu.is_menu_open():
		return
	if board_camera_controller.has_method("is_suppressing_click") and board_camera_controller.is_suppressing_click():
		return

	var coord: Vector2i = _coord_from_pointer_event(event)
	if !board_model.has_cell_coord(coord):
		return

	_on_cell_selected(coord)
	get_viewport().set_input_as_handled()


func _is_click_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and !mouse_event.pressed
	if event is InputEventScreenTouch and !Input.is_emulating_touch_from_mouse():
		var touch_event := event as InputEventScreenTouch
		return touch_event.index == 0 and !touch_event.pressed
	return false


func _coord_from_pointer_event(event: InputEvent) -> Vector2i:
	var screen_pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		screen_pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch:
		screen_pos = (event as InputEventScreenTouch).position
	var local_pos: Vector2 = board_view.get_global_transform_with_canvas().affine_inverse() * screen_pos
	return board_view.coord_from_local_pos(local_pos)


func _setup_parallax() -> void:
	var parallax: Node2D = PARALLAX_SCRIPT.new() as Node2D
	parallax.name = "ParallaxBackground"
	add_child(parallax)
	move_child(parallax, 0)
	if parallax.has_method("setup_random_game_background"):
		parallax.setup_random_game_background()
	if parallax.has_method("set_camera"):
		var camera: Camera2D = get_node_or_null("BoardCamera") as Camera2D
		parallax.set_camera(camera)


func _finish_entry_sequence() -> void:
	var play_intro: bool = ScreenFader.consume_board_intro()
	if play_intro:
		board_field.position = _board_field_target_position + Vector2(INTRO_FROM_RIGHT_OFFSET, 0.0)

	if ScreenFader.is_awaiting_reveal() or ScreenFader.is_fading():
		if play_intro:
			await _play_entry_reveal_with_intro()
		else:
			await ScreenFader.fade_in(ScreenFader.FADE_REVEAL_SEC)
		_intro_animating = false
		return

	if play_intro:
		await _play_board_intro()

	_intro_animating = false


func _play_entry_reveal_with_intro() -> void:
	_intro_animating = true
	var stop_position: Vector2 = _board_field_target_position + INTRO_STOP_SHORT_OF_TARGET
	var board_tween: Tween = create_tween()
	board_tween.set_ease(Tween.EASE_OUT)
	board_tween.set_trans(Tween.TRANS_CUBIC)
	board_tween.tween_property(board_field, "position", stop_position, INTRO_SLIDE_SEC)
	var fade_tween: Tween = ScreenFader.fade_in_tween(ScreenFader.FADE_REVEAL_SEC)
	await board_tween.finished
	await fade_tween.finished
	_intro_animating = false


func _play_board_intro() -> void:
	_intro_animating = true
	var stop_position: Vector2 = _board_field_target_position + INTRO_STOP_SHORT_OF_TARGET
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(board_field, "position", stop_position, INTRO_SLIDE_SEC)
	await tween.finished
	_intro_animating = false


func _on_cell_selected(coord: Vector2i) -> void:
	if game_pause_menu.is_menu_open():
		return

	if phase == Phase.GAME_OVER:
		hud_controller.show_validation_reason(move_validator.GAME_OVER)
		return

	var selected_color: int = board_model.get_value(coord)
	var validation: Dictionary = move_validator.validate(coord, selected_color, board_model, game_session_state)
	if !validation["ok"]:
		hud_controller.show_validation_reason(validation["reason"])
		return

	_process_move(selected_color)


func _process_move(selected_color: int) -> void:
	var move_generation_at_start: int = _move_generation
	var move_result: Dictionary = board_model.apply_move(selected_color)
	if !move_result["applied"]:
		hud_controller.show_validation_reason(move_result["reason"])
		return

	game_session_state.register_move(move_result)
	transition_player.play_wave(
		move_result,
		board_view,
		cell_fx_layer_manager,
		board_presentation_state,
		move_generation_at_start
	)


func _on_wave_playback_finished(move_result: Dictionary, move_generation: int) -> void:
	if move_generation != _move_generation:
		return

	if move_result.get("solved", false):
		phase = Phase.GAME_OVER
		game_session_state.finish_game()
		show_game_over_ui()


func _on_active_waves_changed(activity_count: int) -> void:
	game_session_state.set_animating(activity_count > 0)


func _on_session_state_changed() -> void:
	hud_controller.apply_layout()
	hud_controller.sync_from_session(game_session_state)


func show_game_over_ui() -> void:
	game_over_ui.turns = game_session_state.turns
	game_over_ui.present()


func _on_game_over_ui_play_again() -> void:
	var scene_path: String = scene_file_path
	if scene_path.is_empty():
		scene_path = "res://scenes/game/game_small.tscn"
	await ScreenFader.transition_standard(scene_path)


func _on_game_over_ui_show_map() -> void:
	game_over_ui.hide()


func _on_game_over_ui_switch_to_main() -> void:
	await ScreenFader.transition_standard(MAIN_SCENE_PATH)


func _setup_board_for_new_session() -> void:
	board_field_setup.apply(board_model, board_view)
	if cell_fx_layer_manager.has_method("configure_for_board"):
		cell_fx_layer_manager.configure_for_board(board_model)
	_store_initial_board_snapshot()
	board_presentation_state.reset_from_model(board_model, board_view)
	board_model.refresh_available_move_values()
	game_session_state.start_new_game(game_session_state.max_turns)
	hud_controller.apply_layout()
	hud_controller.sync_from_session(game_session_state)


func _store_initial_board_snapshot() -> void:
	_initial_board_cells.clear()
	for coord in board_model.cells:
		_initial_board_cells[coord] = board_model.get_value(coord)


func _restore_initial_board_snapshot() -> void:
	board_model.cells.clear()
	for coord in _initial_board_cells:
		board_model.cells[coord] = _initial_board_cells[coord]
	board_model.refresh_available_move_values()


func _on_pause_restart_requested() -> void:
	_move_generation += 1
	transition_player.stop_all()
	game_over_ui.hide()
	if game_pause_menu.has_method("close_menu"):
		game_pause_menu.close_menu()
	phase = Phase.IDLE
	game_session_state.set_animating(false)

	if board_field_setup.is_random_mode():
		board_field_setup.apply(board_model, board_view)
		_store_initial_board_snapshot()
	else:
		_restore_initial_board_snapshot()

	if cell_fx_layer_manager.has_method("configure_for_board"):
		cell_fx_layer_manager.configure_for_board(board_model)
	board_presentation_state.reset_from_model(board_model, board_view)
	board_model.refresh_available_move_values()
	game_session_state.start_new_game(game_session_state.max_turns)
	hud_controller.apply_layout()
	hud_controller.sync_from_session(game_session_state)
	board_field.position = _board_field_target_position


func _on_pause_main_menu_requested() -> void:
	await ScreenFader.transition_standard(MAIN_SCENE_PATH)
