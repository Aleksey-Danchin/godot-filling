extends Node

## Прокси: клики и камера обрабатываются в BoardCameraController.
signal cell_selected(coord: Vector2i)

@export var camera_controller_path: NodePath = NodePath("../BoardCameraController")

var _camera_controller: Node = null


func _ready() -> void:
	if camera_controller_path.is_empty():
		return
	_camera_controller = get_node_or_null(camera_controller_path)
	if _camera_controller != null and _camera_controller.has_signal("cell_selected"):
		_camera_controller.cell_selected.connect(_forward_cell_selected)


func _forward_cell_selected(coord: Vector2i) -> void:
	cell_selected.emit(coord)
