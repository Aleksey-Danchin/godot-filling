extends Node

signal panned
signal zoomed

@export var camera_path: NodePath = NodePath("../BoardCamera")
@export var min_zoom: float = 0.25
@export var max_zoom: float = 2.5
@export var zoom_step: float = 0.1
@export var drag_threshold_px: float = 12.0
@export var allow_pan: bool = true
@export var allow_zoom: bool = true

var _camera: Camera2D = null
var _default_position: Vector2 = Vector2.ZERO
var _default_zoom: Vector2 = Vector2.ONE

var _pointer_down: bool = false
var _press_screen_pos: Vector2 = Vector2.ZERO
var _release_screen_pos: Vector2 = Vector2.ZERO
var _max_pointer_travel_px: float = 0.0
var _drag_camera_start: Vector2 = Vector2.ZERO
var _drag_screen_start: Vector2 = Vector2.ZERO
var _using_mouse: bool = false
var _pan_emitted: bool = false
var _zoom_emitted: bool = false


func _ready() -> void:
	if !camera_path.is_empty():
		_camera = get_node(camera_path) as Camera2D
	if _camera != null:
		_camera.make_current()
		_default_position = _camera.position
		_default_zoom = _camera.zoom


func set_allow_pan(value: bool) -> void:
	allow_pan = value


func set_allow_zoom(value: bool) -> void:
	allow_zoom = value


func _input(event: InputEvent) -> void:
	if _camera == null:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMagnifyGesture:
		_handle_magnify(event as InputEventMagnifyGesture)


func is_suppressing_click() -> bool:
	return _max_pointer_travel_px >= drag_threshold_px


func reset_view() -> void:
	if _camera == null:
		return
	_camera.position = _default_position
	_camera.zoom = _default_zoom
	reset_gesture_hints()


func reset_gesture_hints() -> void:
	_pan_emitted = false
	_zoom_emitted = false


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer(event.position, true)
		else:
			_release_screen_pos = event.position
			_end_pointer()
		return

	if !allow_zoom:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_apply_zoom(1.0 + zoom_step)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_apply_zoom(1.0 - zoom_step)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if !_pointer_down or !_using_mouse:
		return
	_track_pointer_travel(event.position)
	if is_suppressing_click():
		_apply_grab_pan(event.position)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if Input.is_emulating_touch_from_mouse() or event.index != 0:
		return
	if event.pressed:
		_begin_pointer(event.position, false)
	else:
		_release_screen_pos = event.position
		_end_pointer()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if Input.is_emulating_touch_from_mouse() or event.index != 0 or _using_mouse:
		return
	_track_pointer_travel(event.position)
	if is_suppressing_click():
		_apply_grab_pan(event.position)


func _handle_magnify(event: InputEventMagnifyGesture) -> void:
	if !allow_zoom:
		return
	_apply_zoom(1.0 + event.factor)


func _begin_pointer(screen_pos: Vector2, from_mouse: bool) -> void:
	_pointer_down = true
	_using_mouse = from_mouse
	_press_screen_pos = screen_pos
	_release_screen_pos = screen_pos
	_max_pointer_travel_px = 0.0
	_drag_camera_start = _camera.position
	_drag_screen_start = screen_pos


func _track_pointer_travel(screen_pos: Vector2) -> void:
	var was_below_threshold: bool = _max_pointer_travel_px < drag_threshold_px
	_max_pointer_travel_px = maxf(
		_max_pointer_travel_px,
		_press_screen_pos.distance_to(screen_pos)
	)
	if was_below_threshold and _max_pointer_travel_px >= drag_threshold_px:
		_drag_camera_start = _camera.position
		_drag_screen_start = _press_screen_pos


func _end_pointer() -> void:
	if _pointer_down:
		_track_pointer_travel(_release_screen_pos)
	_pointer_down = false
	call_deferred("_reset_pointer_travel")


func _reset_pointer_travel() -> void:
	_max_pointer_travel_px = 0.0


func _apply_grab_pan(current_screen_pos: Vector2) -> void:
	if !is_suppressing_click():
		return
	if !allow_pan:
		return
	var viewport := _camera.get_viewport()
	var inv := viewport.get_canvas_transform().affine_inverse()
	var delta_screen: Vector2 = _drag_screen_start - current_screen_pos
	_camera.position = _drag_camera_start + inv.basis_xform(delta_screen)
	if !_pan_emitted:
		_pan_emitted = true
		panned.emit()


func _apply_zoom(multiplier: float) -> void:
	if !allow_zoom:
		return
	var target: Vector2 = _camera.zoom * multiplier
	target.x = clampf(target.x, min_zoom, max_zoom)
	target.y = clampf(target.y, min_zoom, max_zoom)
	_camera.zoom = target
	if !_zoom_emitted:
		_zoom_emitted = true
		zoomed.emit()
