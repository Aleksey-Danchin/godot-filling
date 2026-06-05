extends Control

const GAME_SMALL_SCENE := "res://scenes/game/game_small.tscn"
const GAME_LARGE_SCENE := "res://scenes/game/game_large.tscn"
const GAME_RANDOM_SCENE := "res://scenes/game/game_random.tscn"
const SETTINGS_PANEL := preload("res://scenes/settings/settings_scene.tscn")
const ABOUT_PANEL := preload("res://scenes/about/about_scene.tscn")
const SLIDE_TRANSITION_SCRIPT := preload("res://widgets/menu_navigation/menu_slide_transition.gd")

@onready var _content_host: Control = $ContentHost
@onready var _menu_slot: Control = $ContentHost/MenuSlideSlot
@onready var _menu_panel: Control = $ContentHost/MenuSlideSlot/MenuPanel

var _slide_transition: Node = null
var _overlay_slot: Control = null
var _is_sliding: bool = false


func _ready() -> void:
	_slide_transition = _content_host.get_node_or_null("MenuSlideTransition")
	if _slide_transition == null:
		_slide_transition = Node.new()
		_slide_transition.name = "MenuSlideTransition"
		_slide_transition.set_script(SLIDE_TRANSITION_SCRIPT)
		_content_host.add_child(_slide_transition)
	_content_host.clip_contents = true
	_content_host.resized.connect(_on_content_host_resized)
	_on_content_host_resized()


func _on_content_host_resized() -> void:
	if _slide_transition == null or _is_sliding:
		return
	_slide_transition.sync_menu_slot(_menu_slot, _content_host)


func _on_small_game_pressed() -> void:
	await ScreenFader.transition_menu_to_game(GAME_SMALL_SCENE)


func _on_large_game_pressed() -> void:
	await ScreenFader.transition_menu_to_game(GAME_LARGE_SCENE)


func _on_random_game_pressed() -> void:
	await ScreenFader.transition_menu_to_game(GAME_RANDOM_SCENE)


func _on_settings_pressed() -> void:
	await _open_overlay_panel(SETTINGS_PANEL)


func _on_about_pressed() -> void:
	await _open_overlay_panel(ABOUT_PANEL)


func _open_overlay_panel(packed: PackedScene) -> void:
	if _is_sliding or _overlay_slot != null:
		return

	_is_sliding = true
	var panel: Control = packed.instantiate() as Control
	_overlay_slot = _slide_transition.create_overlay_slot(panel, _content_host)
	if panel.has_signal("back_requested"):
		panel.back_requested.connect(_on_overlay_back_requested)

	await _slide_transition.slide_forward(_content_host, _menu_slot, _overlay_slot)
	_is_sliding = false


func _on_overlay_back_requested() -> void:
	await _slide_back_to_menu()


func _slide_back_to_menu() -> void:
	if _is_sliding or _overlay_slot == null:
		return

	_is_sliding = true
	var outgoing_slot: Control = _overlay_slot
	_overlay_slot = null
	_menu_slot.show()
	await _slide_transition.slide_back(_content_host, outgoing_slot, _menu_slot)
	outgoing_slot.queue_free()
	_is_sliding = false
