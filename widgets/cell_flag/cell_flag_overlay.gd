extends Node2D

## Контейнер флагов над волнами. Дочерние CellFlagBanner расставляются в редакторе сцены.

const OVERLAY_Z_INDEX := 256

var _board_view: TileMapLayer = null
var _flags_by_coord: Dictionary = {}


func _ready() -> void:
	z_as_relative = false
	z_index = OVERLAY_Z_INDEX


func prepare_for_session(board_view: TileMapLayer, board_field: Node2D, board_model: Node) -> void:
	_board_view = board_view
	_flags_by_coord.clear()

	var used_coords: Dictionary = {}
	var invalid_flags: Array[CellFlagBanner] = []

	for child in get_children():
		if !(child is CellFlagBanner):
			continue
		var flag: CellFlagBanner = child as CellFlagBanner
		flag.reset_for_session(flag.use_random_color)

		if board_model == null or !board_model.has_method("has_cell_coord"):
			invalid_flags.append(flag)
			continue
		if !board_model.has_cell_coord(flag.cell_coord) or used_coords.has(flag.cell_coord):
			invalid_flags.append(flag)
			continue

		flag.snap_to_cell(board_view)
		used_coords[flag.cell_coord] = true
		_flags_by_coord[flag.cell_coord] = flag

	for flag in invalid_flags:
		flag.queue_free()


func on_cell_wave_started(coord: Vector2i) -> void:
	if !_flags_by_coord.has(coord):
		return
	var flag: CellFlagBanner = _flags_by_coord[coord] as CellFlagBanner
	if flag.is_depleted():
		return
	_flags_by_coord.erase(coord)
	flag.play_knock_off()


func tick_after_move() -> void:
	for child in get_children():
		if !(child is CellFlagBanner):
			continue
		var flag: CellFlagBanner = child as CellFlagBanner
		if !flag.is_tickable():
			continue
		flag.apply_turn_tick()
