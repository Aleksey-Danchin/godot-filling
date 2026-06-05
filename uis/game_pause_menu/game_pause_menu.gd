extends CanvasLayer

signal restart_requested
signal main_menu_requested

@onready var menu_overlay: Control = $MenuOverlay
@onready var burger_button: Button = $BurgerButton
@onready var center_panel: PanelContainer = $MenuOverlay/CenterPanel


func _ready() -> void:
	menu_overlay.hide()
	menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if center_panel != null:
		center_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func is_menu_open() -> bool:
	return menu_overlay.visible


func close_menu() -> void:
	menu_overlay.hide()


func _on_burger_pressed() -> void:
	if menu_overlay.visible:
		close_menu()
	else:
		menu_overlay.show()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		close_menu()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_menu()


func _on_back_to_game_pressed() -> void:
	close_menu()


func _on_restart_pressed() -> void:
	close_menu()
	restart_requested.emit()


func _on_main_menu_pressed() -> void:
	close_menu()
	main_menu_requested.emit()
