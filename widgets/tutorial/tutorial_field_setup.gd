extends Node

enum Pattern { TAP_TWO, CAMERA_QUADS, TURN_LIMIT, FLAGS }

@export var pattern: Pattern = Pattern.TAP_TWO


func is_random_mode() -> bool:
	return false


func apply(board_model: Node, board_view: TileMapLayer) -> void:
	board_view.clear()
	match pattern:
		Pattern.TAP_TWO:
			_fill_tap_two(board_view)
		Pattern.CAMERA_QUADS:
			_fill_camera_quads(board_view)
		Pattern.TURN_LIMIT:
			_fill_turn_limit(board_view)
		Pattern.FLAGS:
			_fill_flags(board_view)
	board_view.import_cells_to_model(board_model)


func _paint_rect(board_view: TileMapLayer, x0: int, y0: int, w: int, h: int, color: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			board_view.render_coord_value(Vector2i(x, y), color)


func _fill_tap_two(board_view: TileMapLayer) -> void:
	board_view.render_coord_value(Vector2i(0, 0), 1)
	board_view.render_coord_value(Vector2i(1, 0), 2)


func _fill_camera_quads(board_view: TileMapLayer) -> void:
	_paint_rect(board_view, 0, 0, 6, 6, 1)
	_paint_rect(board_view, 6, 0, 6, 6, 2)
	_paint_rect(board_view, 0, 6, 6, 6, 3)
	_paint_rect(board_view, 6, 6, 6, 6, 4)


func _fill_turn_limit(board_view: TileMapLayer) -> void:
	# 3x2: старт (0,0)=1, сосед (1,0)=2, дальше (2,0)=1 — победа за 2 хода при лимите 2+
	board_view.render_coord_value(Vector2i(0, 0), 1)
	board_view.render_coord_value(Vector2i(1, 0), 2)
	board_view.render_coord_value(Vector2i(2, 0), 1)
	board_view.render_coord_value(Vector2i(0, 1), 2)
	board_view.render_coord_value(Vector2i(1, 1), 1)
	board_view.render_coord_value(Vector2i(2, 1), 2)


func _fill_flags(board_view: TileMapLayer) -> void:
	board_view.render_coord_value(Vector2i(0, 0), 1)
	board_view.render_coord_value(Vector2i(1, 0), 2)
	board_view.render_coord_value(Vector2i(2, 0), 1)
	board_view.render_coord_value(Vector2i(0, 1), 2)
	board_view.render_coord_value(Vector2i(1, 1), 1)
	board_view.render_coord_value(Vector2i(2, 1), 2)
