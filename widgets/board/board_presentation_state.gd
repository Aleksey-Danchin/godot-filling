extends Node

## Визуально применённое состояние TileMapLayer; фактическая модель — в BoardModel.

var current_values: Dictionary = {}
var last_applied_wave_by_coord: Dictionary = {}
var pending_commits_by_coord: Dictionary = {}
## coord -> { wave_id: true } — волна затронула клетку и ещё не прислала commit.
var expected_commits_by_coord: Dictionary = {}
## coord -> { wave_id: new_value } — итоговое значение клетки после волны (для старта FX следующей).
var wave_target_values_by_coord: Dictionary = {}


func reset_from_model(board_model: Node, board_view: TileMapLayer) -> void:
	clear()
	if board_model == null or board_view == null:
		return

	for coord in board_model.cells:
		var value: int = board_model.get_value(coord)
		current_values[coord] = value
		board_view.render_coord_value(coord, value)


func clear() -> void:
	current_values.clear()
	last_applied_wave_by_coord.clear()
	pending_commits_by_coord.clear()
	expected_commits_by_coord.clear()
	wave_target_values_by_coord.clear()


func register_wave_cells(wave_id: int, cells: Array, new_value: int) -> void:
	for coord_variant in cells:
		var coord: Vector2i = coord_variant
		if !expected_commits_by_coord.has(coord):
			expected_commits_by_coord[coord] = {}
		expected_commits_by_coord[coord][wave_id] = true

		if !wave_target_values_by_coord.has(coord):
			wave_target_values_by_coord[coord] = {}
		wave_target_values_by_coord[coord][wave_id] = new_value


func get_value(coord: Vector2i) -> int:
	return int(current_values.get(coord, -1))


func get_texture_for_coord(coord: Vector2i, board_view: TileMapLayer) -> Texture2D:
	var value: int = get_value(coord)
	if value < 0:
		return null
	return board_view.get_texture_for_value(value)


func get_visual_value_at_wave_start(coord: Vector2i, wave_id: int) -> int:
	var value: int = get_value(coord)
	if value < 0:
		return -1

	if !wave_target_values_by_coord.has(coord):
		return value

	var targets: Dictionary = wave_target_values_by_coord[coord]
	var prior_wave_ids: Array = []
	for prior_wave_id in targets.keys():
		if int(prior_wave_id) < wave_id:
			prior_wave_ids.append(int(prior_wave_id))

	prior_wave_ids.sort()
	for prior_wave_id in prior_wave_ids:
		value = int(targets[prior_wave_id])

	return value


func get_texture_for_coord_at_wave_start(
	coord: Vector2i,
	wave_id: int,
	board_view: TileMapLayer
) -> Texture2D:
	var value: int = get_visual_value_at_wave_start(coord, wave_id)
	if value < 0:
		return null
	return board_view.get_texture_for_value(value)


func request_cell_commit(wave_id: int, coord: Vector2i, value: int, board_view: TileMapLayer) -> void:
	if board_view == null:
		return

	_mark_commit_received(wave_id, coord)

	if !pending_commits_by_coord.has(coord):
		pending_commits_by_coord[coord] = {}

	var pending: Dictionary = pending_commits_by_coord[coord]
	pending[wave_id] = value
	_flush_coord_commits(coord, board_view)


func _mark_commit_received(wave_id: int, coord: Vector2i) -> void:
	if !expected_commits_by_coord.has(coord):
		return
	var expected: Dictionary = expected_commits_by_coord[coord]
	expected.erase(wave_id)
	if expected.is_empty():
		expected_commits_by_coord.erase(coord)


func _flush_coord_commits(coord: Vector2i, board_view: TileMapLayer) -> void:
	var pending: Dictionary = pending_commits_by_coord.get(coord, {})
	if pending.is_empty() and !expected_commits_by_coord.has(coord):
		pending_commits_by_coord.erase(coord)
		return

	var last_applied: int = int(last_applied_wave_by_coord.get(coord, -1))

	while true:
		var next_wave_id: int = last_applied + 1
		if pending.has(next_wave_id):
			var value: int = int(pending[next_wave_id])
			current_values[coord] = value
			board_view.render_coord_value(coord, value)
			last_applied = next_wave_id
			pending.erase(next_wave_id)
			continue

		if _is_wave_expected_on_coord(coord, next_wave_id):
			break

		# Волна next_wave_id не затрагивает эту клетку — пропускаем в очереди.
		if !_has_higher_pending_or_expected(coord, next_wave_id, pending):
			break

		last_applied = next_wave_id

	last_applied_wave_by_coord[coord] = last_applied

	if pending.is_empty():
		pending_commits_by_coord.erase(coord)
	else:
		pending_commits_by_coord[coord] = pending


func _is_wave_expected_on_coord(coord: Vector2i, wave_id: int) -> bool:
	if !expected_commits_by_coord.has(coord):
		return false
	return expected_commits_by_coord[coord].has(wave_id)


func _has_higher_pending_or_expected(coord: Vector2i, wave_id: int, pending: Dictionary) -> bool:
	for pending_wave_id in pending.keys():
		if int(pending_wave_id) > wave_id:
			return true

	if !expected_commits_by_coord.has(coord):
		return false

	for expected_wave_id in expected_commits_by_coord[coord].keys():
		if int(expected_wave_id) > wave_id:
			return true

	return false
