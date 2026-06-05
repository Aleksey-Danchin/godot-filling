extends TextureProgressBar

const BAR_BG := preload("res://assets/Prinbles_Asset_Robin (v 1.1) (9_5_2023)/png/Bar/Background.png")
const BAR_FILL := preload("res://assets/Prinbles_Asset_Robin (v 1.1) (9_5_2023)/png/Bar/Line.png")


func _ready() -> void:
	texture_under = BAR_BG
	texture_progress = BAR_FILL
	texture_filter = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_orientation(GameSettings.turns_progress_orientation)


func apply_orientation(orientation: String) -> void:
	_apply_orientation(orientation)


func sync_from_session(session: Node) -> void:
	if session == null:
		return
	max_value = maxf(float(session.max_turns), 1.0)
	value = clampf(float(session.turns), 0.0, max_value)


func _apply_orientation(orientation: String) -> void:
	if orientation == "vertical":
		fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
		rotation_degrees = 0.0
		custom_minimum_size = Vector2(52, 280)
	else:
		fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		rotation_degrees = 0.0
		custom_minimum_size = Vector2(320, 52)
