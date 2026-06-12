extends CanvasLayer

const PROGRESS_THICKNESS := 48.0
const PROGRESS_MARGIN := 20.0

@export var turns_label_path: NodePath
@export var status_label_path: NodePath
@export var horizontal_progress_path: NodePath

var turns_label: Label = null
var status_label: Label = null
var horizontal_progress: ProgressBar = null
var hud_card: PanelContainer = null
var root_control: Control = null
var top_margin: MarginContainer = null
var _turn_limit_ui_visible: bool = true


func _ready() -> void:
	if !turns_label_path.is_empty():
		turns_label = get_node(turns_label_path)
	if !status_label_path.is_empty():
		status_label = get_node(status_label_path)
	if !horizontal_progress_path.is_empty():
		horizontal_progress = get_node(horizontal_progress_path) as ProgressBar

	root_control = get_node_or_null("Root") as Control
	if root_control != null:
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_margin = root_control.get_node_or_null("TopMargin") as MarginContainer
		hud_card = root_control.find_child("HudCard", true, false) as PanelContainer
	if turns_label != null:
		turns_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status_label != null:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	get_viewport().size_changed.connect(_on_viewport_changed)
	call_deferred("_on_viewport_changed")


func _on_viewport_changed() -> void:
	_fit_to_viewport()
	call_deferred("_finish_layout")


func _finish_layout() -> void:
	if top_margin != null:
		top_margin.queue_sort()
	apply_layout()


func _fit_to_viewport() -> void:
	if root_control == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	root_control.set_position(Vector2.ZERO)
	root_control.set_size(viewport_size)

	if top_margin != null:
		top_margin.set_position(Vector2.ZERO)
		top_margin.set_size(viewport_size)


func set_turn_limit_ui_visible(visible: bool) -> void:
	_turn_limit_ui_visible = visible
	if horizontal_progress != null:
		horizontal_progress.visible = visible
	if turns_label != null:
		turns_label.visible = visible
	apply_layout()


func sync_from_session(session: Node) -> void:
	if turns_label != null and _turn_limit_ui_visible:
		turns_label.text = "Ходов: %d/%d" % [session.turns, session.max_turns]

	if status_label == null:
		pass
	elif !session.is_active:
		status_label.text = "Игра завершена"
	elif session.is_animating:
		status_label.text = "Переход..."
	else:
		status_label.text = "Игра идет"

	if horizontal_progress != null and _turn_limit_ui_visible \
			and horizontal_progress.has_method("sync_from_session"):
		horizontal_progress.sync_from_session(session)


func apply_layout() -> void:
	if horizontal_progress != null:
		horizontal_progress.visible = _turn_limit_ui_visible
		if horizontal_progress.get_parent() is BoxContainer:
			horizontal_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			horizontal_progress.custom_minimum_size = Vector2(0.0, PROGRESS_THICKNESS)

	if hud_card != null and hud_card.get_parent() is BoxContainer:
		hud_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	if top_margin != null:
		top_margin.add_theme_constant_override("margin_left", int(PROGRESS_MARGIN))
		top_margin.add_theme_constant_override("margin_top", int(PROGRESS_MARGIN))
		top_margin.add_theme_constant_override("margin_right", int(PROGRESS_MARGIN))
		top_margin.add_theme_constant_override("margin_bottom", int(PROGRESS_MARGIN))
		top_margin.queue_sort()


func show_validation_reason(reason: String) -> void:
	if status_label != null and reason != "":
		status_label.text = "Ход отклонен: %s" % reason
