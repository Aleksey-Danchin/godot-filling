extends CanvasLayer

signal show_map
signal play_again
signal switch_to_main

const OPEN_DUR := 0.38
const SLIDE_PX := 96.0

@onready var backdrop: ColorRect = $ColorRect
@onready var content_body: MarginContainer = $Control/MarginContainer
@onready var label_2: Label = $Control/MarginContainer/VBoxContainer/Label2

var turns: int = 0:
	set(value):
		turns = value
		if label_2 != null:
			label_2.text = "Уровень пройден за %d ходов!" % value

var _body_rest_position: Vector2 = Vector2.ZERO
var _backdrop_target_alpha: float = 0.51
var _is_presenting: bool = false


func _ready() -> void:
	hide()
	_body_rest_position = content_body.position
	_backdrop_target_alpha = backdrop.color.a


func present() -> void:
	if _is_presenting:
		return

	_is_presenting = true
	show()
	var backdrop_color: Color = backdrop.color
	backdrop.color = Color(backdrop_color.r, backdrop_color.g, backdrop_color.b, 0.0)
	content_body.position = _body_rest_position + Vector2(0.0, SLIDE_PX)

	var tween: Tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(backdrop, "color:a", _backdrop_target_alpha, OPEN_DUR)
	tween.tween_property(content_body, "position", _body_rest_position, OPEN_DUR)
	await tween.finished
	_is_presenting = false


func _on_button_1_pressed() -> void:
	show_map.emit()


func _on_button_2_pressed() -> void:
	play_again.emit()


func _on_button_3_pressed() -> void:
	switch_to_main.emit()
