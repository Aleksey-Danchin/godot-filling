extends Node2D

signal finished

@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: GPUParticles2D = $GPUParticles2D

@export var shake_light_sec: float = 0.15
@export var shake_strong_sec: float = 0.22
@export var scale_peak: float = 1.3
@export var scale_down_sec: float = 0.2

var _busy: bool = false
var _active_tween: Tween = null
var _on_finished_apply: Callable = Callable()


func play_flip(
	old_tex: Texture2D,
	new_tex: Texture2D,
	on_finished_apply: Callable,
	shake_light: float = -1.0,
	shake_strong: float = -1.0,
	use_particles: bool = true
) -> void:
	_stop_active_tween()
	_busy = true
	_on_finished_apply = on_finished_apply
	var light_dur: float = shake_light if shake_light > 0.0 else shake_light_sec
	var strong_dur: float = shake_strong if shake_strong > 0.0 else shake_strong_sec

	if sprite == null:
		_apply_tile_from_animation()
		_end_play()
		return

	sprite.texture = old_tex
	sprite.visible = true
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE

	var build_dur: float = light_dur + strong_dur
	await _shake_build(build_dur, light_dur, strong_dur)

	sprite.texture = new_tex

	var particle_wait: float = 0.0
	if use_particles and particles != null and old_tex != null:
		particle_wait = _emit_particles_above_waves(old_tex)

	_stop_active_tween()
	_active_tween = create_tween()
	_active_tween.tween_property(sprite, "scale", Vector2.ONE, scale_down_sec)

	if _active_tween != null and _active_tween.is_valid():
		await _active_tween.finished
	if particle_wait > 0.0:
		await get_tree().create_timer(particle_wait).timeout

	_apply_tile_from_animation()
	_end_play()


func _shake_build(total_dur: float, light_dur: float, strong_dur: float) -> void:
	_stop_active_tween()
	_active_tween = create_tween()
	var tween: Tween = _active_tween

	tween.tween_property(sprite, "scale", Vector2(scale_peak, scale_peak), total_dur)

	var light_amp: float = 2.0
	var strong_amp: float = 5.0
	_append_shake_keyframes(tween, light_dur, light_amp, 0.0)
	_append_shake_keyframes(tween, strong_dur, strong_amp, light_dur)

	await tween.finished


func _append_shake_keyframes(tween: Tween, duration: float, amplitude: float, time_offset: float) -> void:
	var quarter: float = duration * 0.25
	var origin := Vector2.ZERO
	var offsets: Array[Vector2] = [
		origin + Vector2(amplitude, 0.0),
		origin + Vector2(-amplitude, amplitude * 0.5),
		origin + Vector2(0.0, -amplitude),
		origin
	]
	var t: float = time_offset
	for offset in offsets:
		tween.parallel().tween_property(sprite, "position", offset, quarter).set_delay(t)
		t += quarter


func _apply_tile_from_animation() -> void:
	if _on_finished_apply.is_valid():
		_on_finished_apply.call()
	_on_finished_apply = Callable()


func _end_play() -> void:
	_stop_active_tween()
	_on_finished_apply = Callable()
	if sprite != null:
		sprite.visible = false
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
	_reset_particles_draw_order()
	_busy = false
	finished.emit()


func is_busy() -> bool:
	return _busy


func prepare_for_play() -> void:
	_stop_active_tween()
	_on_finished_apply = Callable()
	_busy = false
	if sprite != null:
		sprite.visible = false
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
	_reset_particles_draw_order()


func _emit_particles_above_waves(old_tex: Texture2D) -> float:
	particles.texture = old_tex
	particles.top_level = true
	particles.z_as_relative = false
	particles.z_index = _resolve_particles_z_index()
	particles.global_position = global_position
	particles.restart()
	particles.emitting = true
	return particles.lifetime


func _reset_particles_draw_order() -> void:
	if particles == null:
		return
	particles.emitting = false
	particles.top_level = false
	particles.z_as_relative = true
	particles.z_index = 11
	particles.position = Vector2.ZERO


func _resolve_particles_z_index() -> int:
	var node: Node = self
	while node != null:
		if node.has_method("get_particles_z_index"):
			return node.get_particles_z_index()
		node = node.get_parent()
	return 100


func _stop_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
