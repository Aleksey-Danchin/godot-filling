extends Control

signal back_requested
signal item_pressed(scene_path: String)

@onready var _title: Label = $MenuPanel/VBox/Title
@onready var _buttons_vbox: VBoxContainer = $MenuPanel/VBox/MenuButtons/ButtonsVBox


func setup(title_text: String, items: Array) -> void:
	_title.text = title_text
	for child in _buttons_vbox.get_children():
		child.queue_free()
	if items.is_empty():
		var soon := Label.new()
		soon.text = "Скоро"
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		soon.add_theme_font_size_override("font_size", 48)
		_buttons_vbox.add_child(soon)
	for item in items:
		var path: String = item.get("path", "")
		var label: String = item.get("label", "")
		if path.is_empty():
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(600, 144)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.text = label
		button.pressed.connect(_on_item_pressed.bind(path))
		_buttons_vbox.add_child(button)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 32)
	_buttons_vbox.add_child(spacer)
	var back := Button.new()
	back.custom_minimum_size = Vector2(600, 144)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.text = "← Назад"
	back.pressed.connect(_on_back_pressed)
	_buttons_vbox.add_child(back)


func _on_item_pressed(scene_path: String) -> void:
	item_pressed.emit(scene_path)


func _on_back_pressed() -> void:
	back_requested.emit()
