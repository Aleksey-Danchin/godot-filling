extends Node2D

enum Mode { MENU_DRIFT, CAMERA_FOLLOW }

const BACKGROUNDS_ROOT := "res://assets/New free backgrounds part2/"
const MENU_BACKGROUND_FOLDER := BACKGROUNDS_ROOT + "background 1/"
const GAME_BACKGROUND_IDS: Array[int] = [2, 3, 4]

@export var mode: Mode = Mode.MENU_DRIFT
@export var background_folder: String = MENU_BACKGROUND_FOLDER
@export var camera_path: NodePath = NodePath("")
@export var menu_scroll_speed: float = 44.0
@export var game_auto_scroll_speed: float = 24.0
@export_range(0.0, 1.0, 0.01) var game_camera_parallax_factor: float = 0.33
@export var game_drift_amplitude_x: float = 0.0
@export var game_drift_period_sec: float = 32.0
@export var layer_parallax_factors: Array[float] = [0.12, 0.22, 0.34, 0.48, 0.62]
@export var tile_cover_margin: float = 1.08

var _camera: Camera2D = null
var _camera_anchor: Vector2 = Vector2.ZERO
var _layers: Array[Dictionary] = []
var _menu_scroll_x: float = 0.0
var _game_scroll_x: float = 0.0
var _game_time: float = 0.0
var _last_camera_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	z_index = -100
	set_process(true)
	call_deferred("_rebuild_layers")
	if mode == Mode.CAMERA_FOLLOW:
		call_deferred("_bind_camera")


func setup_menu_background() -> void:
	mode = Mode.MENU_DRIFT
	_menu_scroll_x = 0.0
	background_folder = MENU_BACKGROUND_FOLDER
	_rebuild_layers()


func setup_random_game_background() -> void:
	mode = Mode.CAMERA_FOLLOW
	_game_scroll_x = 0.0
	_game_time = 0.0
	var bg_id: int = GAME_BACKGROUND_IDS[randi() % GAME_BACKGROUND_IDS.size()]
	background_folder = BACKGROUNDS_ROOT + "background %d/" % bg_id
	_rebuild_layers()
	_bind_camera()


func set_camera(camera: Camera2D) -> void:
	_camera = camera
	if _camera != null:
		_camera_anchor = _camera.global_position
		_last_camera_zoom = _camera.zoom


func _bind_camera() -> void:
	if !camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Camera2D
	if _camera == null:
		var game_root: Node = get_parent()
		if game_root is CanvasLayer:
			game_root = game_root.get_parent()
		if game_root != null:
			_camera = game_root.get_node_or_null("BoardCamera") as Camera2D
	if _camera != null:
		_camera_anchor = _camera.global_position
		_last_camera_zoom = _camera.zoom


func _process(delta: float) -> void:
	if _layers.is_empty():
		return

	if mode == Mode.MENU_DRIFT:
		_apply_menu_scroll(delta)
		return

	if _camera == null:
		return

	_apply_game_parallax(delta)


func _rebuild_layers() -> void:
	for layer in _layers:
		if layer.has("root"):
			layer["root"].queue_free()
	_layers.clear()

	var layer_paths: PackedStringArray = _collect_layer_texture_paths(background_folder)
	if layer_paths.is_empty():
		push_warning("ParallaxBackground: no layers in %s" % background_folder)
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = _view_center(viewport_size)

	for texture_path in layer_paths:
		var tex: Texture2D = load(texture_path) as Texture2D
		if tex == null:
			continue
		_layers.append(_create_tiled_layer(tex, viewport_size, center))


func _create_tiled_layer(tex: Texture2D, viewport_size: Vector2, center: Vector2) -> Dictionary:
	var cover_scale: float = _cover_scale_for_texture(tex, viewport_size)
	var tile_width: float = tex.get_size().x * cover_scale
	if tile_width <= 1.0:
		tile_width = 1.0

	var tiles_needed: int = int(ceil(viewport_size.x / tile_width)) + 3
	var layer_root := Node2D.new()
	layer_root.name = "Layer_%s" % tex.resource_path.get_file().get_basename()
	add_child(layer_root)

	var sprites: Array[Sprite2D] = []
	var half_count: int = tiles_needed / 2
	for tile_index in range(tiles_needed):
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.centered = true
		sprite.scale = Vector2.ONE * cover_scale
		sprite.position = Vector2(
			center.x + float(tile_index - half_count) * tile_width,
			center.y
		)
		layer_root.add_child(sprite)
		sprites.append(sprite)

	return {
		"root": layer_root,
		"sprites": sprites,
		"tile_width": tile_width,
		"center": center,
	}


func _collect_layer_texture_paths(folder: String) -> PackedStringArray:
	var result: PackedStringArray = []
	if folder.is_empty():
		return result

	for index in range(1, 6):
		var numbered: String = folder + "%d.png" % index
		if ResourceLoader.exists(numbered):
			result.append(numbered)

	if result.is_empty():
		var fallback: String = folder + "orig_big.png"
		if ResourceLoader.exists(fallback):
			result.append(fallback)
		else:
			fallback = folder + "orig.png"
			if ResourceLoader.exists(fallback):
				result.append(fallback)

	return result


func _view_center(viewport_size: Vector2) -> Vector2:
	# В игре узел стоит в позиции камеры — центр кадра в локальных (0, 0).
	if mode == Mode.CAMERA_FOLLOW:
		return Vector2.ZERO
	return viewport_size * 0.5


func _cover_scale_for_texture(tex: Texture2D, viewport_size: Vector2) -> float:
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return 1.0
	return maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y) * tile_cover_margin


func _apply_menu_scroll(delta: float) -> void:
	_menu_scroll_x += menu_scroll_speed * delta

	for layer_index in range(_layers.size()):
		var factor: float = _layer_factor(layer_index)
		_apply_layer_scroll(_layers[layer_index], _menu_scroll_x * factor)


func _apply_game_parallax(delta: float) -> void:
	_sync_camera_zoom_anchor()

	var zoom: Vector2 = _camera.zoom
	global_position = _camera.global_position
	scale = Vector2(1.0 / zoom.x, 1.0 / zoom.y)

	var camera_delta: Vector2 = _camera.global_position - _camera_anchor
	var camera_delta_x_screen: float = camera_delta.x * zoom.x
	_game_scroll_x += camera_delta_x_screen * game_camera_parallax_factor
	_camera_anchor = _camera.global_position

	_game_time += delta
	_game_scroll_x += game_auto_scroll_speed * delta

	var drift_x: float = 0.0
	if game_drift_amplitude_x > 0.0:
		var phase: float = _game_time * (TAU / maxf(game_drift_period_sec, 0.01))
		drift_x = sin(phase) * game_drift_amplitude_x

	for layer_index in range(_layers.size()):
		var factor: float = _layer_factor(layer_index)
		var scroll_x: float = _game_scroll_x * factor + drift_x * factor
		_apply_layer_scroll(_layers[layer_index], scroll_x, Vector2.ZERO)


func _apply_layer_scroll(layer: Dictionary, scroll_x: float, center_override: Vector2 = Vector2.INF) -> void:
	var tile_width: float = layer["tile_width"]
	var wrap_offset: float = fposmod(scroll_x, tile_width)
	var center: Vector2 = layer["center"]
	if center_override != Vector2.INF:
		center = center_override

	var sprites: Array = layer["sprites"]
	var sprite_count: int = sprites.size()
	var half_count: int = sprite_count / 2

	for tile_index in range(sprite_count):
		var sprite: Sprite2D = sprites[tile_index]
		var base_x: float = center.x + float(tile_index - half_count) * tile_width
		sprite.position = Vector2(base_x - wrap_offset, center.y)


func _sync_camera_zoom_anchor() -> void:
	if _camera == null:
		return
	if _camera.zoom != _last_camera_zoom:
		_camera_anchor = _camera.global_position
		_last_camera_zoom = _camera.zoom


func _layer_factor(index: int) -> float:
	if layer_parallax_factors.is_empty():
		return float(index + 1) * 0.15
	if index < layer_parallax_factors.size():
		return layer_parallax_factors[index]
	return layer_parallax_factors[-1]
