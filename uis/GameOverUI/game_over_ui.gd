extends CanvasLayer


signal show_map
signal play_again
signal switch_to_main


@onready var label_2: Label = $Control/MarginContainer/VBoxContainer/Label2


var turns: int = 0:
	set(value):
		turns = value
		label_2.text = "Уровень пройден за %d ходов!" % value

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_1_pressed() -> void:
	show_map.emit()


func _on_button_2_pressed() -> void:
	play_again.emit()


func _on_button_3_pressed() -> void:
	switch_to_main.emit()
