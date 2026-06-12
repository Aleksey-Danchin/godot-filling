@tool
class_name CellFlagBanner
extends Node2D

enum BannerColor { BLUE, GREEN, RED }
enum FlagState { ACTIVE, DEPLETED, KNOCKED_OFF }

const COLOR_NAMES: PackedStringArray = ["Blue", "Green", "Red"]
const PNG_DIR := "res://assets/Banners/PNG/Simple/Floor-Quiet/"
const FRAME_SUFFIXES: PackedStringArray = ["0", "1", "2", "3", "4", "5"]
const ANIM_FPS := 10.0
const DEFAULT_BANNER_SCALE := 0.15
const CELL_PIVOT := Vector2(0.5, 0.75)
const FLAG_PIVOT := Vector2(0.5, 1.0)

@export var cell_coord: Vector2i = Vector2i.ZERO:
	set(value):
		cell_coord = value
		call_deferred("_sync_placement_from_cell_coord")

@export var use_random_color: bool = false
@export var banner_color: BannerColor = BannerColor.BLUE:
	set(value):
		banner_color = _sanitize_banner_color(value)
		_apply_color()

@export_range(0.05, 1.0, 0.01) var banner_scale: float = DEFAULT_BANNER_SCALE:
	set(value):
		banner_scale = value
		scale = Vector2(banner_scale, banner_scale)
		call_deferred("_sync_placement_from_cell_coord")

@export var randomize_anim_speed: bool = true
@export_range(0.5, 2.0, 0.01) var anim_speed_min: float = 0.75
@export_range(0.5, 2.0, 0.01) var anim_speed_max: float = 1.35

@export var counter_label_offset: Vector2 = Vector2(6, 8)

@export_range(0, 99) var initial_counter: int = 3

var counter: int = 0
var state: FlagState = FlagState.ACTIVE

static var _shared_sprite_frames: Dictionary = {}
var _home_position: Vector2 = Vector2.ZERO
var _snapping: bool = false
var _programmatic_placement: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _counter_label: Label = $CounterLabel


func _ready() -> void:
	scale = Vector2(banner_scale, banner_scale)
	counter = initial_counter
	_apply_color()
	_refresh_counter_label()
	_apply_state_visuals()
	call_deferred("_sync_placement_from_cell_coord")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and !_programmatic_placement:
		call_deferred("_sync_placement_from_drag")


func reset_for_session(randomize_color: bool = false) -> void:
	state = FlagState.ACTIVE
	visible = true
	rotation = 0.0
	modulate = Color.WHITE
	counter = initial_counter
	if randomize_color or use_random_color:
		pick_random_color()
	elif !use_random_color:
		_apply_color()
	_apply_random_anim_speed()
	_refresh_counter_label()
	_apply_state_visuals()


func pick_random_color() -> BannerColor:
	banner_color = randi() % BannerColor.size() as BannerColor
	return banner_color


func _sanitize_banner_color(value: int) -> BannerColor:
	if value < 0 or value >= BannerColor.size():
		return BannerColor.BLUE
	return value as BannerColor


func is_depleted() -> bool:
	return state == FlagState.DEPLETED


func is_tickable() -> bool:
	return state == FlagState.ACTIVE and counter > 0


func apply_turn_tick() -> void:
	if !is_tickable():
		return
	counter -= 1
	if counter <= 0:
		counter = 0
		state = FlagState.DEPLETED
	_refresh_counter_label()
	_apply_state_visuals()


func play_knock_off() -> void:
	if state != FlagState.ACTIVE:
		return
	state = FlagState.KNOCKED_OFF
	var start_pos: Vector2 = position
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", start_pos + Vector2(0.0, -10.0), 0.08)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", start_pos + Vector2(0.0, -5.0), 0.05)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.set_parallel(true)
	tween.tween_property(self, "position", start_pos + Vector2(0.0, 280.0), 0.85)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "rotation", rotation + TAU * 2.5, 0.85)
	await tween.finished
	visible = false


func snap_to_cell(board_view: TileMapLayer) -> void:
	if board_view == null:
		return
	var anchor: Vector2 = _cell_anchor_in_overlay(board_view, cell_coord)
	_home_position = anchor - _flag_pivot_offset_scaled()
	_apply_snapped_position(_home_position)
	call_deferred("_clear_programmatic_placement")


func _sync_placement_from_cell_coord() -> void:
	var board_view := _find_board_view()
	if board_view == null:
		return
	snap_to_cell(board_view)


func _sync_placement_from_drag() -> void:
	if _snapping or _programmatic_placement or !Engine.is_editor_hint():
		return
	var board_view := _find_board_view()
	if board_view == null:
		return

	var resolved_coord: Vector2i = _resolve_cell_coord_from_position(board_view)
	_snapping = true
	cell_coord = resolved_coord
	_snapping = false
	snap_to_cell(board_view)


func _resolve_cell_coord_from_position(board_view: TileMapLayer) -> Vector2i:
	var overlay := get_parent() as Node2D
	var overlay_pos: Vector2 = overlay.position if overlay != null else Vector2.ZERO
	var anchor_in_overlay: Vector2 = overlay_pos + position + _flag_pivot_offset_scaled()
	var anchor_in_board_view: Vector2 = anchor_in_overlay - board_view.position
	return board_view.coord_from_local_pos(anchor_in_board_view)


func _cell_anchor_in_overlay(board_view: TileMapLayer, coord: Vector2i) -> Vector2:
	return board_view.position + board_view.map_coord_to_pivot(coord, CELL_PIVOT)


func _flag_pivot_offset_scaled() -> Vector2:
	return _flag_pivot_offset_local() * banner_scale


func _flag_pivot_offset_local() -> Vector2:
	var size: Vector2 = _get_banner_size()
	var top_left: Vector2 = Vector2(-size.x * 0.5, -size.y * 0.5)
	return top_left + Vector2(size.x * FLAG_PIVOT.x, size.y * FLAG_PIVOT.y)


func _get_banner_size() -> Vector2:
	if is_node_ready() and _sprite != null and _sprite.sprite_frames != null:
		if _sprite.sprite_frames.has_animation("default") and _sprite.sprite_frames.get_frame_count("default") > 0:
			var tex: Texture2D = _sprite.sprite_frames.get_frame_texture("default", 0)
			if tex != null:
				return tex.get_size()
	return Vector2(128.0, 128.0)


func _find_board_view() -> TileMapLayer:
	var overlay := get_parent()
	if overlay == null:
		return null
	var board_field := overlay.get_parent()
	if board_field == null:
		return null
	return board_field.get_node_or_null("BoardView") as TileMapLayer


func _apply_snapped_position(target: Vector2) -> void:
	_programmatic_placement = true
	_snapping = true
	position = target
	_snapping = false


func _clear_programmatic_placement() -> void:
	_programmatic_placement = false


func _apply_color() -> void:
	if !is_node_ready():
		return
	var frames := _frames_for_color(banner_color)
	_sprite.sprite_frames = frames
	if frames.has_animation("default"):
		_sprite.play("default")
	_apply_random_anim_speed()
	call_deferred("_sync_placement_from_cell_coord")


func _frames_for_color(color: BannerColor) -> SpriteFrames:
	if _shared_sprite_frames.has(color):
		return _shared_sprite_frames[color]

	var prefix: String = COLOR_NAMES[color]
	var frames := SpriteFrames.new()
	if !frames.has_animation("default"):
		frames.add_animation("default")
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", ANIM_FPS)

	for suffix in FRAME_SUFFIXES:
		var path := "%s%s-banner-LW-%s.PNG" % [PNG_DIR, prefix, suffix]
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame("default", texture)

	_shared_sprite_frames[color] = frames
	return frames


func _apply_random_anim_speed() -> void:
	if !is_node_ready() or _sprite == null:
		return
	if Engine.is_editor_hint() and !randomize_anim_speed:
		_sprite.speed_scale = 1.0
		return
	if randomize_anim_speed:
		var lo: float = minf(anim_speed_min, anim_speed_max)
		var hi: float = maxf(anim_speed_min, anim_speed_max)
		_sprite.speed_scale = randf_range(lo, hi)
	else:
		_sprite.speed_scale = 1.0


func _center_counter_label() -> void:
	if !is_node_ready() or _counter_label == null:
		return
	_counter_label.reset_size()
	var size: Vector2 = _counter_label.get_minimum_size()
	_counter_label.position = -size * 0.5 + counter_label_offset


func _refresh_counter_label() -> void:
	if !is_node_ready() or _counter_label == null:
		return
	_counter_label.text = str(counter) if state == FlagState.ACTIVE and counter > 0 else ""
	_counter_label.visible = state == FlagState.ACTIVE and counter > 0
	_center_counter_label()


func _apply_state_visuals() -> void:
	if !is_node_ready():
		return
	if state == FlagState.DEPLETED:
		modulate = Color(0.58, 0.58, 0.58, 1.0)
	elif state == FlagState.ACTIVE:
		modulate = Color.WHITE
