extends Node2D

const CELL_FX_SCENE := preload("res://widgets/cell_fx/cell_fx.tscn")

signal slot_freed

@export_range(8, 512) var pool_size: int = 64

## Слой-владелец; узлы пула нельзя резервировать из другого CellFxLayer.
var owner_layer: Node2D = null

var _available: Array[Node2D] = []
var _all: Array[Node2D] = []


func _ready() -> void:
	z_as_relative = true
	_ensure_pool_instances(pool_size)


func get_capacity() -> int:
	return _all.size()


func count_idle_slots() -> int:
	_purge_busy_from_available()
	return _available.size()


func reserve_slot_for_layer(layer: Node2D) -> Node2D:
	if owner_layer != null and layer != owner_layer:
		push_warning("CellFxPool: запрет резерва — пул принадлежит другому слою волны.")
		return null
	return reserve_slot()


func reserve_slot() -> Node2D:
	_purge_busy_from_available()
	if _available.is_empty():
		return null
	var fx: Node2D = _available.pop_back()
	if fx.get_parent() != self:
		push_warning("CellFxPool: узел FX не является дочерним этим пулом.")
		_return_to_pool(fx)
		return null
	return fx


func grow_pool_to(target_size: int) -> void:
	var target: int = clampi(target_size, 8, 512)
	pool_size = target
	_ensure_pool_instances(target)


func play_on_reserved(
	fx: Node2D,
	local_pos: Vector2,
	old_tex: Texture2D,
	new_tex: Texture2D,
	on_finished_apply: Callable,
	shake_light: float,
	shake_strong: float,
	use_particles: bool
) -> Node2D:
	if fx == null or fx.get_parent() != self:
		return null
	fx.position = local_pos
	fx.visible = true
	fx.play_flip(old_tex, new_tex, on_finished_apply, shake_light, shake_strong, use_particles)
	return fx


func play_at_async(
	local_pos: Vector2,
	old_tex: Texture2D,
	new_tex: Texture2D,
	on_finished_apply: Callable,
	shake_light: float,
	shake_strong: float,
	use_particles: bool
) -> Node2D:
	var fx: Node2D = await acquire_idle()
	return play_on_reserved(
		fx, local_pos, old_tex, new_tex, on_finished_apply, shake_light, shake_strong, use_particles
	)


func acquire_idle() -> Node2D:
	_purge_busy_from_available()
	while _available.is_empty():
		await slot_freed
		_purge_busy_from_available()
	return _available.pop_back()


func stop_all() -> void:
	for fx in _all:
		if fx.get_parent() != self:
			continue
		if fx.has_method("prepare_for_play"):
			fx.prepare_for_play()
		fx.visible = false
	_available.clear()
	for fx in _all:
		if fx.get_parent() != self:
			continue
		if fx.has_method("is_busy") and !fx.is_busy():
			_available.append(fx)
	slot_freed.emit()


func _ensure_pool_instances(target_size: int) -> void:
	while _all.size() < target_size:
		var fx: Node2D = _add_fx_instance()
		_available.append(fx)


func _add_fx_instance() -> Node2D:
	var fx: Node2D = CELL_FX_SCENE.instantiate()
	add_child(fx)
	fx.visible = false
	fx.set_meta(&"fx_pool", self)
	fx.finished.connect(_on_fx_finished.bind(fx))
	_all.append(fx)
	return fx


func _return_to_pool(fx: Node2D) -> void:
	if fx == null or fx not in _all:
		return
	if fx.has_method("prepare_for_play"):
		fx.prepare_for_play()
	fx.visible = false
	if !_available.has(fx) and fx.get_parent() == self:
		if fx.has_method("is_busy") and !fx.is_busy():
			_available.append(fx)


func _purge_busy_from_available() -> void:
	var i: int = _available.size() - 1
	while i >= 0:
		var fx: Node2D = _available[i]
		if fx.get_parent() != self or (fx.has_method("is_busy") and fx.is_busy()):
			_available.remove_at(i)
		i -= 1


func _on_fx_finished(fx: Node2D) -> void:
	if fx.get_parent() != self:
		return
	fx.visible = false
	if fx.has_method("is_busy") and fx.is_busy():
		return
	if fx in _all and !_available.has(fx):
		_available.append(fx)
		slot_freed.emit()
