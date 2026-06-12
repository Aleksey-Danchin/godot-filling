extends Node2D

const SIZE_IN_TILES := 1.35
const DILATE_SHADER := preload("res://widgets/tutorial/tutorial_cell_tap_dilate.gdshader")
const TINT_WHITE_SHADER := preload("res://widgets/tutorial/tutorial_cell_tap_tint_white.gdshader")
const OUTLINE_WIDTH := 4

@onready var _outline_sprite: AnimatedSprite2D = $OutlineSprite
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	z_as_relative = false
	z_index = 200
	hide_hint()
	var frames := TutorialHintFrames.frames_for_cell_tap()
	_apply_sprite_frames(frames)
	_apply_materials()


func show_at_cell(board_view: TileMapLayer, coord: Vector2i) -> void:
	if board_view == null:
		hide_hint()
		return

	var tile_size: float = float(board_view.tile_set.tile_size.x) if board_view.tile_set != null else 16.0
	var frame_size: float = 200.0
	if _sprite.sprite_frames != null and _sprite.sprite_frames.get_frame_count("default") > 0:
		var tex: Texture2D = _sprite.sprite_frames.get_frame_texture("default", 0)
		if tex != null:
			frame_size = maxf(tex.get_size().x, 1.0)

	var cell_scale := Vector2.ONE * (tile_size * SIZE_IN_TILES / frame_size)
	_sprite.scale = cell_scale
	_outline_sprite.scale = cell_scale

	var cell_center: Vector2 = board_view.map_coord_to_local_center(coord)
	position = board_view.position + cell_center
	_play_sprites()
	show()


func hide_hint() -> void:
	_stop_sprites()
	hide()


func _apply_sprite_frames(frames: SpriteFrames) -> void:
	_sprite.sprite_frames = frames
	_outline_sprite.sprite_frames = frames


func _apply_materials() -> void:
	var dilate := ShaderMaterial.new()
	dilate.shader = DILATE_SHADER
	dilate.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	_outline_sprite.material = dilate

	var tint := ShaderMaterial.new()
	tint.shader = TINT_WHITE_SHADER
	_sprite.material = tint


func _play_sprites() -> void:
	for sprite in [_outline_sprite, _sprite]:
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("default"):
			sprite.play("default")


func _stop_sprites() -> void:
	_outline_sprite.stop()
	_sprite.stop()
