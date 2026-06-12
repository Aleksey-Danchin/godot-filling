extends ProgressBar

const BAR_BG := preload("res://assets/Prinbles_Asset_Robin (v 1.1) (9_5_2023)/png/Bar/Background.png")
const BAR_FILL := preload("res://assets/Prinbles_Asset_Robin (v 1.1) (9_5_2023)/png/Bar/Line.png")


func _ready() -> void:
	show_percentage = false
	fill_mode = 0
	custom_minimum_size = Vector2(0.0, 48.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("background", _make_bar_style(BAR_BG))
	add_theme_stylebox_override("fill", _make_bar_style(BAR_FILL))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync_from_session(session: Node) -> void:
	if session == null:
		return
	max_value = maxf(float(session.max_turns), 1.0)
	value = clampf(float(session.turns), 0.0, max_value)


func _make_bar_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 16.0
	style.texture_margin_top = 12.0
	style.texture_margin_right = 16.0
	style.texture_margin_bottom = 12.0
	return style
