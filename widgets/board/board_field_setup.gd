extends Node

enum SetupMode { IMPORT_FROM_TILEMAP, RANDOM }

@export var setup_mode: SetupMode = SetupMode.IMPORT_FROM_TILEMAP
@export_range(0, 512) var bootstrap_columns: int = 0
@export_range(0, 512) var bootstrap_rows: int = 0
@export var always_bootstrap: bool = false


func is_random_mode() -> bool:
	return setup_mode == SetupMode.RANDOM


func apply(board_model: Node, board_view: TileMapLayer) -> void:
	match setup_mode:
		SetupMode.IMPORT_FROM_TILEMAP:
			_apply_import(board_model, board_view)
		SetupMode.RANDOM:
			board_model.initialize_rectangular(
				board_model.rows,
				board_model.columns,
				board_model.color_count
			)


func _apply_import(board_model: Node, board_view: TileMapLayer) -> void:
	if always_bootstrap and bootstrap_columns > 0 and bootstrap_rows > 0:
		board_view.fill_random_grid(bootstrap_columns, bootstrap_rows, board_model.color_count)
	elif bootstrap_columns > 0 and bootstrap_rows > 0 and board_view.get_used_cells().is_empty():
		board_view.fill_random_grid(bootstrap_columns, bootstrap_rows, board_model.color_count)
	board_view.import_cells_to_model(board_model)
