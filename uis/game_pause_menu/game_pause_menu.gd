extends CanvasLayer

signal restart_requested
signal main_menu_requested

const OPEN_DUR := 0.38
const SLIDE_PX := 88.0
const PROGRESS_MARGIN := 20.0
const PROGRESS_THICKNESS := 48.0
const BURGER_HEIGHT := 88.0
const TOOLBAR_GAP := 12.0

@onready var menu_overlay: Control = $MenuOverlay
@onready var backdrop: ColorRect = $MenuOverlay/Backdrop
@onready var burger_button: Button = $BurgerButton
@onready var center_panel: PanelContainer = $MenuOverlay/CenterPanel

var _panel_rest_top: float = 0.0
var _panel_rest_bottom: float = 0.0
var _backdrop_target_alpha: float = 0.45
var _is_animating: bool = false


func _ready() -> void:
	menu_overlay.hide()
	menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if center_panel != null:
		center_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_panel_rest_top = center_panel.offset_top
		_panel_rest_bottom = center_panel.offset_bottom
	_backdrop_target_alpha = backdrop.color.a
	get_viewport().size_changed.connect(_update_burger_position)
	call_deferred("_update_burger_position")


func _update_burger_position(_arg: Variant = null) -> void:
	if burger_button == null:
		return
	var top: float = PROGRESS_MARGIN + PROGRESS_THICKNESS + TOOLBAR_GAP
	burger_button.offset_top = top
	burger_button.offset_bottom = top + BURGER_HEIGHT


func is_menu_open() -> bool:
	return menu_overlay.visible


func close_menu() -> void:
	if !menu_overlay.visible:
		return
	await _animate_close()


func _on_burger_pressed() -> void:
	if menu_overlay.visible:
		await close_menu()
	else:
		await open_menu()


func open_menu() -> void:
	if _is_animating or menu_overlay.visible:
		return

	_is_animating = true
	menu_overlay.show()
	var backdrop_color: Color = backdrop.color
	backdrop.color = Color(backdrop_color.r, backdrop_color.g, backdrop_color.b, 0.0)
	center_panel.offset_top = _panel_rest_top - SLIDE_PX
	center_panel.offset_bottom = _panel_rest_bottom - SLIDE_PX

	var tween: Tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(backdrop, "color:a", _backdrop_target_alpha, OPEN_DUR)
	tween.tween_property(center_panel, "offset_top", _panel_rest_top, OPEN_DUR)
	tween.tween_property(center_panel, "offset_bottom", _panel_rest_bottom, OPEN_DUR)
	await tween.finished
	_is_animating = false


func _animate_close() -> void:
	if _is_animating:
		return

	_is_animating = true
	var close_dur: float = OPEN_DUR * 0.85
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(backdrop, "color:a", 0.0, close_dur)
	tween.tween_property(center_panel, "offset_top", _panel_rest_top - SLIDE_PX, close_dur)
	tween.tween_property(center_panel, "offset_bottom", _panel_rest_bottom - SLIDE_PX, close_dur)
	await tween.finished
	menu_overlay.hide()
	backdrop.color.a = _backdrop_target_alpha
	center_panel.offset_top = _panel_rest_top
	center_panel.offset_bottom = _panel_rest_bottom
	_is_animating = false


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		await close_menu()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		await close_menu()


func _on_back_to_game_pressed() -> void:
	await close_menu()


func _on_restart_pressed() -> void:
	await close_menu()
	restart_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
