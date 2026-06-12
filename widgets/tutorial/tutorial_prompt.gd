extends CanvasLayer

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/BottomAnchor/Panel
@onready var _hint_host: Control = $Root/BottomAnchor/Panel/Margin/VBox/HintHost
@onready var _hint_sprite: AnimatedSprite2D = $Root/BottomAnchor/Panel/Margin/VBox/HintHost/HintSprite
@onready var _label: Label = $Root/BottomAnchor/Panel/Margin/VBox/MessageLabel


func _ready() -> void:
	layer = 50
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_prompt()


func set_text(text: String) -> void:
	if _label != null:
		_label.text = text


func set_hint_texture_or_animation(path: String) -> void:
	if _hint_host == null or _hint_sprite == null:
		return
	if path.is_empty():
		_hint_host.visible = false
		_hint_sprite.sprite_frames = null
		return

	var frames := TutorialHintFrames.frames_for(path)
	if frames == null:
		_hint_host.visible = false
		_hint_sprite.sprite_frames = null
		return

	_hint_sprite.sprite_frames = frames
	_hint_sprite.play("default")
	_hint_host.visible = true


func show_prompt(text: String, hint_path: String = "") -> void:
	set_text(text)
	set_hint_texture_or_animation(hint_path)
	show()


func hide_prompt() -> void:
	if _hint_sprite != null:
		_hint_sprite.stop()
	hide()
