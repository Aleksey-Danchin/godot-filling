extends CanvasLayer

@export var turns_label_path: NodePath
@export var status_label_path: NodePath
@export var horizontal_progress_path: NodePath
@export var vertical_progress_path: NodePath

var turns_label: Label = null
var status_label: Label = null
var horizontal_progress: TextureProgressBar = null
var vertical_progress: TextureProgressBar = null


func _ready() -> void:
	if !turns_label_path.is_empty():
		turns_label = get_node(turns_label_path)
	if !status_label_path.is_empty():
		status_label = get_node(status_label_path)
	if !horizontal_progress_path.is_empty():
		horizontal_progress = get_node(horizontal_progress_path)
	if !vertical_progress_path.is_empty():
		vertical_progress = get_node(vertical_progress_path)

	var root: Control = get_node_or_null("Root")
	if root != null:
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if turns_label != null:
		turns_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status_label != null:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_apply_progress_orientation(GameSettings.turns_progress_orientation)


func sync_from_session(session: Node) -> void:
	if turns_label != null:
		turns_label.text = "Ходов: %d/%d" % [session.turns, session.max_turns]

	if status_label == null:
		pass
	elif !session.is_active:
		status_label.text = "Игра завершена"
	elif session.is_animating:
		status_label.text = "Переход..."
	else:
		status_label.text = "Игра идет"

	if horizontal_progress != null and horizontal_progress.has_method("sync_from_session"):
		horizontal_progress.sync_from_session(session)
	if vertical_progress != null and vertical_progress.has_method("sync_from_session"):
		vertical_progress.sync_from_session(session)


func apply_progress_orientation(orientation: String) -> void:
	_apply_progress_orientation(orientation)
	if horizontal_progress != null and horizontal_progress.has_method("apply_orientation"):
		horizontal_progress.apply_orientation(orientation)
	if vertical_progress != null and vertical_progress.has_method("apply_orientation"):
		vertical_progress.apply_orientation(orientation)


func show_validation_reason(reason: String) -> void:
	if status_label != null and reason != "":
		status_label.text = "Ход отклонен: %s" % reason


func _apply_progress_orientation(orientation: String) -> void:
	var show_horizontal: bool = orientation != "vertical"
	if horizontal_progress != null:
		horizontal_progress.visible = show_horizontal
	if vertical_progress != null:
		vertical_progress.visible = !show_horizontal
