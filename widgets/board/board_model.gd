@tool
extends Node

signal board_initialized()
signal board_changed(changed_cells: Array[Vector2i])

@export_range(1, 512) var rows: int = 9
@export_range(1, 512) var columns: int = 6
@export_range(1, 32) var color_count: int = 8
@export var start_coord: Vector2i = Vector2i.ZERO

var cells: Dictionary[Vector2i, int] = {}
## Типы ячеек на границе активной зоны, которыми можно расширить область.
var available_move_values: Dictionary[int, bool] = {}


func _ready() -> void:
	if Engine.is_editor_hint() and cells.is_empty():
		initialize_rectangular(rows, columns, color_count)


func initialize_rectangular(target_rows: int, target_columns: int, target_color_count: int = 8) -> void:
	rows = max(1, target_rows)
	columns = max(1, target_columns)
	color_count = max(1, target_color_count)
	cells.clear()

	var rng := RandomNumberGenerator.new()
	for y in range(rows):
		for x in range(columns):
			cells[Vector2i(x, y)] = rng.randi_range(1, color_count)

	board_initialized.emit()
	board_changed.emit(get_all_coords())
	refresh_available_move_values()


func is_move_value_available(value: int) -> bool:
	return available_move_values.has(value)


func refresh_available_move_values() -> void:
	available_move_values.clear()
	if !cells.has(start_coord):
		return

	var active_value: int = cells[start_coord]
	var active_region: Dictionary = _collect_active_region()

	for coord in active_region:
		for neighbor in get_neighbors(coord):
			if active_region.has(neighbor):
				continue
			var border_value: int = cells[neighbor]
			if border_value != active_value:
				available_move_values[border_value] = true


func _collect_active_region() -> Dictionary:
	var result: Dictionary = {}
	if !cells.has(start_coord):
		return result

	var active_value: int = cells[start_coord]
	var queue: Array[Vector2i] = [start_coord]
	var visited := {}

	while !queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true

		if cells[current] != active_value:
			continue

		result[current] = true
		for neighbor in get_neighbors(current):
			if !visited.has(neighbor):
				queue.append(neighbor)

	return result


func get_all_coords() -> Array[Vector2i]:
	return cells.keys()


func has_cell_coord(coord: Vector2i) -> bool:
	return cells.has(coord)


func get_value(coord: Vector2i) -> int:
	return cells.get(coord, -1)


func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	for direction in directions:
		var candidate := coord + direction
		if cells.has(candidate):
			result.append(candidate)

	return result


func apply_move(next_value: int) -> Dictionary:
	var empty_changed: Array[Vector2i] = []
	var empty_waves: Array = []
	var fail := {
		"applied": false,
		"changed_cells": empty_changed,
		"wave_layers": empty_waves,
		"old_value": -1,
		"new_value": next_value,
		"solved": false
	}

	if !cells.has(start_coord):
		fail["reason"] = "INVALID_START"
		return fail

	var old_value: int = cells[start_coord]
	if old_value == next_value:
		fail["reason"] = "NO_OP_MOVE"
		fail["solved"] = get_is_solved()
		return fail

	var wave_layers: Array = []
	var changed_cells: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start_coord]
	var visited := {}

	while !frontier.is_empty():
		var layer: Array[Vector2i] = []
		var next_frontier: Array[Vector2i] = []
		var next_seen := {}

		for current in frontier:
			if visited.has(current):
				continue
			visited[current] = true

			if cells[current] != old_value:
				continue

			cells[current] = next_value
			layer.append(current)
			changed_cells.append(current)

			for neighbor in get_neighbors(current):
				if !visited.has(neighbor) and !next_seen.has(neighbor):
					next_seen[neighbor] = true
					next_frontier.append(neighbor)

		if !layer.is_empty():
			wave_layers.append(layer)
		frontier = next_frontier

	board_changed.emit(changed_cells)
	refresh_available_move_values()
	return {
		"applied": true,
		"reason": "OK",
		"changed_cells": changed_cells,
		"wave_layers": wave_layers,
		"wave_root": start_coord,
		"old_value": old_value,
		"new_value": next_value,
		"solved": get_is_solved()
	}


func get_is_solved() -> bool:
	if cells.is_empty():
		return true

	var first_coord: Vector2i = cells.keys()[0]
	var first_value: int = cells[first_coord]
	for value in cells.values():
		if value != first_value:
			return false

	return true
