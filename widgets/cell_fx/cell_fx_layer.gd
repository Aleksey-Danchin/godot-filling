extends Node2D

const CELL_FX_POOL_SCRIPT := preload("res://widgets/cell_fx/cell_fx_pool.gd")

@export_range(8, 512) var pool_size: int = 64

var wave_id: int = -1
var busy: bool = false

var _pool: Node2D = null


func _ready() -> void:
	z_as_relative = true
	_ensure_pool()


func claim(p_wave_id: int) -> void:
	busy = true
	wave_id = p_wave_id


func release() -> void:
	busy = false
	wave_id = -1


func get_pool() -> Node2D:
	_ensure_pool()
	return _pool


func get_pool_capacity() -> int:
	_ensure_pool()
	if _pool.has_method("get_capacity"):
		return _pool.get_capacity()
	return pool_size


func stop_all() -> void:
	if _pool != null and _pool.has_method("stop_all"):
		_pool.stop_all()


func resize_pool(target_size: int) -> void:
	pool_size = clampi(target_size, 8, 512)
	_ensure_pool()
	if _pool.has_method("grow_pool_to"):
		_pool.grow_pool_to(pool_size)


func _ensure_pool() -> void:
	if _pool != null:
		if _pool.owner_layer != self:
			_pool.owner_layer = self
		return

	_pool = Node2D.new()
	_pool.name = "CellFxPool"
	_pool.set_script(CELL_FX_POOL_SCRIPT)
	_pool.owner_layer = self
	_pool.set("pool_size", pool_size)
	add_child(_pool)
