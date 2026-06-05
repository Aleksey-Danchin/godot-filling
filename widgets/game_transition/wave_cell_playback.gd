class_name WaveCellPlayback
extends RefCounted

## Воспроизведение FX одной клетки; визуальный коммит — через BoardPresentationState.


static func play_cell(
	wave_id: int,
	coord: Vector2i,
	board_view: TileMapLayer,
	fx_pool: Node,
	presentation_state: Node,
	old_tex: Texture2D,
	new_tex: Texture2D,
	new_value: int,
	shake_light_sec: float,
	shake_strong_sec: float,
	particle_enabled: bool,
	reserved_fx: Node2D = null
) -> void:
	var overlay_pos: Vector2 = board_view.map_coord_to_local_center(coord)

	var visual_old_tex: Texture2D = old_tex
	if presentation_state != null and presentation_state.has_method("get_texture_for_coord_at_wave_start"):
		var start_tex: Texture2D = presentation_state.get_texture_for_coord_at_wave_start(
			coord, wave_id, board_view
		)
		if start_tex != null:
			visual_old_tex = start_tex

	var on_finished_apply: Callable = Callable()
	if presentation_state != null and presentation_state.has_method("request_cell_commit"):
		on_finished_apply = presentation_state.request_cell_commit.bind(
			wave_id, coord, new_value, board_view
		)

	var fx: Node2D = null
	if reserved_fx != null and fx_pool.has_method("play_on_reserved"):
		fx = fx_pool.play_on_reserved(
			reserved_fx,
			overlay_pos,
			visual_old_tex,
			new_tex,
			on_finished_apply,
			shake_light_sec,
			shake_strong_sec,
			particle_enabled
		)
	elif fx_pool.has_method("play_at_async"):
		fx = await fx_pool.play_at_async(
			overlay_pos,
			visual_old_tex,
			new_tex,
			on_finished_apply,
			shake_light_sec,
			shake_strong_sec,
			particle_enabled
		)

	if fx == null:
		return

	await await_fx(fx)


static func await_fx(fx: Node2D) -> void:
	if fx == null:
		return
	if fx.has_method("is_busy") and !fx.is_busy():
		return
	await fx.finished
