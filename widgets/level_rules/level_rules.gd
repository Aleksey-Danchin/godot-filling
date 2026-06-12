extends Node

@export var enable_flags: bool = true
@export var enable_turn_limit: bool = true
@export_range(1, 999) var max_turns: int = 25


func apply(
	game_session: Node,
	hud_controller: Node,
	cell_flag_overlay: Node2D,
	pause_menu: Node = null
) -> void:
	if game_session != null and game_session.has_method("configure_turn_limit"):
		game_session.configure_turn_limit(enable_turn_limit, max_turns)

	if cell_flag_overlay != null:
		cell_flag_overlay.visible = enable_flags

	if hud_controller != null and hud_controller.has_method("set_turn_limit_ui_visible"):
		hud_controller.set_turn_limit_ui_visible(enable_turn_limit)

	if pause_menu != null and pause_menu.has_method("set_progress_toolbar_visible"):
		pause_menu.set_progress_toolbar_visible(enable_turn_limit)
