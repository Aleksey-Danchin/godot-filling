extends Control

const GAME_SMALL_SCENE := "res://scenes/game/game_small.tscn"
const GAME_LARGE_SCENE := "res://scenes/game/game_large.tscn"
const GAME_RANDOM_SCENE := "res://scenes/game/game_random.tscn"
const TUTORIAL_TAP_SCENE := "res://scenes/tutorial/tutorial_tap.tscn"
const TUTORIAL_CAMERA_SCENE := "res://scenes/tutorial/tutorial_camera.tscn"
const TUTORIAL_TURN_LIMIT_SCENE := "res://scenes/tutorial/tutorial_turn_limit.tscn"
const TUTORIAL_FLAGS_SCENE := "res://scenes/tutorial/tutorial_flags.tscn"
const SETTINGS_PANEL := preload("res://scenes/settings/settings_scene.tscn")
const ABOUT_PANEL := preload("res://scenes/about/about_scene.tscn")
const SUBMENU_PANEL := preload("res://uis/menu_submenu/menu_submenu_panel.tscn")
const SLIDE_TRANSITION_SCRIPT := preload("res://widgets/menu_navigation/menu_slide_transition.gd")

const SUBMENU_TUTORIAL := "tutorial"
const SUBMENU_SCENARIO := "scenario"
const SUBMENU_CHALLENGE := "challenge"

@onready var _content_host: Control = $ContentHost
@onready var _menu_slot: Control = $ContentHost/MenuSlideSlot
@onready var _menu_panel: Control = $ContentHost/MenuSlideSlot/MenuPanel
@onready var _version_label: Label = $ContentHost/MenuSlideSlot/MenuPanel/VBox/VersionLabel

var _slide_transition: Node = null
var _overlay_slot: Control = null
var _is_sliding: bool = false
var _active_submenu_key: String = ""


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
	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.1.0"))

	var restore_key: String = ScreenFader.take_return_submenu()
	if !restore_key.is_empty():
		await get_tree().process_frame
		await _restore_submenu(restore_key)

	if ScreenFader.is_awaiting_reveal():
		await get_tree().process_frame
		await ScreenFader.fade_in(ScreenFader.FADE_REVEAL_SEC)


func _on_content_host_resized() -> void:
	if _slide_transition == null or _is_sliding:
		return
	_slide_transition.sync_menu_slot(_menu_slot, _content_host)


func _on_tutorial_pressed() -> void:
	await _open_submenu_panel("Обучение", _tutorial_items(), SUBMENU_TUTORIAL)


func _on_scenario_pressed() -> void:
	await _open_submenu_panel("Сценарий", [], SUBMENU_SCENARIO)


func _on_challenge_pressed() -> void:
	await _open_submenu_panel("Вызов", _challenge_items(), SUBMENU_CHALLENGE)


func _on_settings_pressed() -> void:
	await _open_overlay_panel(SETTINGS_PANEL)


func _on_about_pressed() -> void:
	await _open_overlay_panel(ABOUT_PANEL)


func _tutorial_items() -> Array:
	return [
		{"label": "Тап", "path": TUTORIAL_TAP_SCENE},
		{"label": "Камера", "path": TUTORIAL_CAMERA_SCENE},
		{"label": "Ходы", "path": TUTORIAL_TURN_LIMIT_SCENE},
		{"label": "Флаги", "path": TUTORIAL_FLAGS_SCENE},
	]


func _challenge_items() -> Array:
	return [
		{"label": "Малое поле", "path": GAME_SMALL_SCENE},
		{"label": "Большое поле", "path": GAME_LARGE_SCENE},
		{"label": "Случайное поле", "path": GAME_RANDOM_SCENE},
	]


func _open_submenu_panel(title_text: String, items: Array, submenu_key: String = "", instant: bool = false) -> void:
	if _is_sliding or _overlay_slot != null:
		return

	_is_sliding = true
	_active_submenu_key = submenu_key
	var panel: Control = SUBMENU_PANEL.instantiate() as Control
	if panel.has_signal("back_requested"):
		panel.back_requested.connect(_on_overlay_back_requested)
	if panel.has_signal("item_pressed"):
		panel.item_pressed.connect(_on_submenu_item_pressed)

	_overlay_slot = _slide_transition.create_overlay_slot(panel, _content_host)
	if panel.has_method("setup"):
		panel.setup(title_text, items)
	if instant:
		_slide_transition.snap_forward(_content_host, _menu_slot, _overlay_slot)
	else:
		await _slide_transition.slide_forward(_content_host, _menu_slot, _overlay_slot)
	_is_sliding = false


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


func _on_submenu_item_pressed(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	if !_active_submenu_key.is_empty():
		ScreenFader.set_return_submenu(_active_submenu_key)
	await ScreenFader.transition_menu_to_game(scene_path)


func _on_overlay_back_requested() -> void:
	await _slide_back_to_menu()


func _slide_back_to_menu() -> void:
	if _is_sliding or _overlay_slot == null:
		return

	_is_sliding = true
	_active_submenu_key = ""
	var outgoing_slot: Control = _overlay_slot
	_overlay_slot = null
	_menu_slot.show()
	await _slide_transition.slide_back(_content_host, outgoing_slot, _menu_slot)
	outgoing_slot.queue_free()
	_is_sliding = false


func _restore_submenu(submenu_key: String) -> void:
	match submenu_key:
		SUBMENU_TUTORIAL:
			await _open_submenu_panel("Обучение", _tutorial_items(), SUBMENU_TUTORIAL, true)
		SUBMENU_SCENARIO:
			await _open_submenu_panel("Сценарий", [], SUBMENU_SCENARIO, true)
		SUBMENU_CHALLENGE:
			await _open_submenu_panel("Вызов", _challenge_items(), SUBMENU_CHALLENGE, true)
