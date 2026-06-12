@tool
extends TileMapLayer

signal cell_clicked(coord: Vector2i)

@export var preview_in_editor: bool = true
@export var preview_model_path: NodePath = NodePath("../../BoardModel")
@export var color_to_source_id: Dictionary[int, int] = {
	1: 0,
	2: 1,
	3: 2,
	4: 3,
	5: 4,
	6: 5,
	7: 6,
	8: 7
}
@export var color_to_atlas: Dictionary[int, Vector2i] = {
	1: Vector2i.ZERO,
	2: Vector2i.ZERO,
	3: Vector2i.ZERO,
	4: Vector2i.ZERO,
	5: Vector2i.ZERO,
	6: Vector2i.ZERO,
	7: Vector2i.ZERO,
	8: Vector2i.ZERO
}

var board_model: Node = null


func _ready() -> void:
	if Engine.is_editor_hint():
		if preview_in_editor:
			call_deferred("_refresh_editor_preview")
		return


func _unhandled_input(event: InputEvent) -> void:
	pass


func _is_click_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and !mouse_event.pressed
	if event is InputEventScreenTouch and !Input.is_emulating_touch_from_mouse():
		var touch_event := event as InputEventScreenTouch
		return touch_event.index == 0 and !touch_event.pressed
	return false


func _enter_tree() -> void:
	if Engine.is_editor_hint() and preview_in_editor:
		call_deferred("_refresh_editor_preview")


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and preview_in_editor:
		_refresh_editor_preview()


func bind_model(model: Node) -> void:
	board_model = model


func render_full(model: Node) -> void:
	bind_model(model)
	clear()
	for coord in board_model.get_all_coords():
		_render_coord(coord)


func apply_changes(changed_cells: Array[Vector2i]) -> void:
	for coord in changed_cells:
		if board_model != null:
			_render_coord(coord)
		else:
			push_warning("BoardView.apply_changes: board_model is not bound")


func render_coords_with_value(coords: Array[Vector2i], value: int) -> void:
	for coord in coords:
		render_coord_value(coord, value)


func render_coord_value(coord: Vector2i, value: int) -> void:
	if !_can_draw_value(value):
		return
	var source_id: int = color_to_source_id[value]
	var atlas_coord: Vector2i = color_to_atlas[value]
	set_cell(coord, source_id, atlas_coord, 0)


func erase_coord(coord: Vector2i) -> void:
	erase_cell(coord)


func map_coord_to_local_center(coord: Vector2i) -> Vector2:
	# Godot 4.x: map_to_local уже возвращает центр клетки.
	return map_to_local(coord)


func map_coord_to_pivot(coord: Vector2i, pivot: Vector2 = Vector2(0.5, 0.75)) -> Vector2:
	var tile_size: Vector2 = Vector2(tile_set.tile_size) if tile_set != null else Vector2(16.0, 16.0)
	var center: Vector2 = map_to_local(coord)
	return center + Vector2(
		tile_size.x * (pivot.x - 0.5),
		tile_size.y * (pivot.y - 0.5)
	)


func get_texture_for_value(value: int) -> Texture2D:
	if tile_set == null or !color_to_source_id.has(value):
		return null
	var source_id: int = color_to_source_id[value]
	var source := tile_set.get_source(source_id)
	if source is TileSetAtlasSource:
		return (source as TileSetAtlasSource).texture
	return null


func get_texture_for_coord(coord: Vector2i) -> Texture2D:
	if tile_set == null:
		return null
	var source_id: int = get_cell_source_id(coord)
	if source_id < 0:
		return null
	var source := tile_set.get_source(source_id)
	if source is TileSetAtlasSource:
		return (source as TileSetAtlasSource).texture
	return null


func coord_from_local_pos(local_pos: Vector2) -> Vector2i:
	return local_to_map(local_pos)


func fill_random_grid(target_columns: int, target_rows: int, color_count: int = 8) -> void:
	clear()
	var rng := RandomNumberGenerator.new()
	var colors: int = maxi(1, color_count)
	for y in range(target_rows):
		for x in range(target_columns):
			var value: int = rng.randi_range(1, colors)
			render_coord_value(Vector2i(x, y), value)


func import_cells_to_model(model: Node) -> void:
	model.cells.clear()
	var used_cells: Array[Vector2i] = get_used_cells()
	if used_cells.is_empty():
		push_warning("BoardView.import_cells_to_model: tilemap is empty")
		return

	var source_to_color: Dictionary = _build_source_to_color_map()
	var min_x: int = 2147483647
	var min_y: int = 2147483647
	var max_x: int = -2147483648
	var max_y: int = -2147483648

	for coord in used_cells:
		var source_id: int = get_cell_source_id(coord)
		if !source_to_color.has(source_id):
			continue
		var color: int = source_to_color[source_id]
		model.cells[coord] = color
		min_x = mini(min_x, coord.x)
		min_y = mini(min_y, coord.y)
		max_x = maxi(max_x, coord.x)
		max_y = maxi(max_y, coord.y)

	if model.cells.is_empty():
		return

	model.columns = max_x - min_x + 1
	model.rows = max_y - min_y + 1
	model.board_initialized.emit()
	model.board_changed.emit(model.get_all_coords())


func _build_source_to_color_map() -> Dictionary:
	var result: Dictionary = {}
	for color in color_to_source_id:
		result[color_to_source_id[color]] = color
	return result


func _render_coord(coord: Vector2i) -> void:
	if board_model == null:
		return

	if !board_model.has_cell_coord(coord):
		erase_cell(coord)
		return

	render_coord_value(coord, board_model.get_value(coord))


func _can_draw_value(value: int) -> bool:
	return tile_set != null and color_to_source_id.has(value) and color_to_atlas.has(value)


func _refresh_editor_preview() -> void:
	if !Engine.is_editor_hint():
		return

	if tile_set == null:
		return

	var model: Node = _resolve_preview_model()
	if model == null:
		return

	if model.cells.is_empty():
		model.initialize_rectangular(model.rows, model.columns, model.color_count)

	render_full(model)


func _resolve_preview_model() -> Node:
	if !preview_model_path.is_empty():
		var by_path := get_node_or_null(preview_model_path)
		if by_path != null:
			return by_path

	var scene_root: Node = get_tree().edited_scene_root
	if scene_root != null:
		var model := scene_root.get_node_or_null("BoardModel")
		if model != null:
			return model

	return null
