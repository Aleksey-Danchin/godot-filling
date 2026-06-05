extends Node2D

const CELL_FX_LAYER_SCRIPT := preload("res://widgets/cell_fx/cell_fx_layer.gd")

@export_range(1, 8) var max_layers: int = 3
@export_range(8, 512) var pool_size_per_layer: int = 64

var _layers: Array[Node2D] = []
## wave_id -> layer node
var _wave_to_layer: Dictionary = {}
var _configured_pool_size: int = 0

const PARTICLES_Z_INDEX := 100


func get_particles_z_index() -> int:
	return PARTICLES_Z_INDEX


func _ready() -> void:
	# Поверх тайлов TileMapLayer; порядок волн — через z_index дочерних CellFxLayer.
	z_as_relative = false
	z_index = 1
	_ensure_layers()


func configure_for_board(board_model: Node) -> void:
	var cell_count: int = 0
	if board_model != null and board_model.has_method("get_all_coords"):
		cell_count = board_model.get_all_coords().size()
	configure_pool_size_for_cell_count(cell_count)


func configure_pool_size_for_cell_count(cell_count: int) -> void:
	var target: int = clampi(maxi(cell_count, 1), 8, 512)
	_configured_pool_size = target
	pool_size_per_layer = target
	_ensure_layers()
	for layer in _layers:
		if layer.has_method("resize_pool"):
			layer.resize_pool(target)


func try_claim_layer(wave_id: int) -> Node2D:
	_ensure_layers()
	for layer in _layers:
		if !layer.busy:
			layer.claim(wave_id)
			_wave_to_layer[wave_id] = layer
			_reorder_layer_z_indices()
			return layer
	return null


func release_layer(wave_id: int) -> void:
	if !_wave_to_layer.has(wave_id):
		return
	var layer: Node2D = _wave_to_layer[wave_id]
	_wave_to_layer.erase(wave_id)
	if layer != null:
		layer.stop_all()
		layer.release()
	_reorder_layer_z_indices()


func stop_all() -> void:
	for layer in _layers:
		layer.stop_all()
		layer.release()
	_wave_to_layer.clear()
	_reorder_layer_z_indices()


func get_pool_capacity_per_layer() -> int:
	_ensure_layers()
	if _configured_pool_size > 0:
		return _configured_pool_size
	if _layers.is_empty():
		return pool_size_per_layer
	return int(_layers[0].pool_size)


func get_total_pool_capacity() -> int:
	return get_pool_capacity_per_layer() * _layers.size()


func get_active_layer_count() -> int:
	var count: int = 0
	for layer in _layers:
		if layer.busy:
			count += 1
	return count


func _ensure_layers() -> void:
	while _layers.size() < max_layers:
		var index: int = _layers.size()
		var layer: Node2D = Node2D.new()
		layer.name = "CellFxLayer%d" % index
		layer.set_script(CELL_FX_LAYER_SCRIPT)
		var target_size: int = pool_size_per_layer
		if _configured_pool_size > 0:
			target_size = _configured_pool_size
		layer.set("pool_size", target_size)
		add_child(layer)
		if layer.has_method("resize_pool"):
			layer.resize_pool(target_size)
		_layers.append(layer)
	_reorder_layer_z_indices()


func _reorder_layer_z_indices() -> void:
	var active: Array[Node2D] = []
	var idle: Array[Node2D] = []
	for layer in _layers:
		if layer.busy:
			active.append(layer)
		else:
			idle.append(layer)

	# Активные слои — по wave_id: старшие волны поверх, независимо от индекса пула.
	active.sort_custom(_compare_active_layers_by_wave_id)

	var z: int = 0
	for layer in idle:
		layer.z_index = z
		z += 1
	for layer in active:
		layer.z_index = z
		z += 1


func _compare_active_layers_by_wave_id(a: Node2D, b: Node2D) -> bool:
	return int(a.wave_id) < int(b.wave_id)
