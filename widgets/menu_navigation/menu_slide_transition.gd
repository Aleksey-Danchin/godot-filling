extends Node

const DURATION_SEC := 0.32


func slide_forward(host: Control, outgoing_slot: Control, incoming_slot: Control) -> void:
	await _slide(host, outgoing_slot, incoming_slot, true)


func slide_back(host: Control, outgoing_slot: Control, incoming_slot: Control) -> void:
	await _slide(host, outgoing_slot, incoming_slot, false)


func snap_forward(host: Control, outgoing_slot: Control, incoming_slot: Control) -> void:
	var panel_size: Vector2 = _panel_size(host)
	_layout_slot(outgoing_slot, panel_size)
	_layout_slot(incoming_slot, panel_size)
	incoming_slot.position = Vector2.ZERO
	incoming_slot.show()
	outgoing_slot.hide()
	outgoing_slot.position = Vector2.ZERO
	host.move_child(incoming_slot, -1)


func create_overlay_slot(panel: Control, host: Control) -> Control:
	var panel_size: Vector2 = _panel_size(host)
	var slot: Control = Control.new()
	slot.name = "OverlaySlideSlot"
	_layout_slot(slot, panel_size)
	host.add_child(slot)
	host.move_child(slot, -1)
	slot.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	return slot


func sync_menu_slot(menu_slot: Control, host: Control) -> void:
	_layout_slot(menu_slot, _panel_size(host))
	menu_slot.position = Vector2.ZERO


func _slide(host: Control, outgoing_slot: Control, incoming_slot: Control, forward: bool) -> void:
	var panel_size: Vector2 = _panel_size(host)
	_layout_slot(outgoing_slot, panel_size)
	_layout_slot(incoming_slot, panel_size)

	var width: float = panel_size.x
	if forward:
		incoming_slot.position = Vector2(width, 0.0)
		outgoing_slot.position = Vector2.ZERO
	else:
		incoming_slot.position = Vector2(-width, 0.0)
		outgoing_slot.position = Vector2.ZERO

	incoming_slot.show()
	outgoing_slot.show()
	host.move_child(incoming_slot, -1)

	await get_tree().process_frame

	var tween: Tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	if forward:
		tween.tween_property(outgoing_slot, "position:x", -width, DURATION_SEC)
		tween.tween_property(incoming_slot, "position:x", 0.0, DURATION_SEC)
	else:
		tween.tween_property(outgoing_slot, "position:x", width, DURATION_SEC)
		tween.tween_property(incoming_slot, "position:x", 0.0, DURATION_SEC)
	await tween.finished

	incoming_slot.position = Vector2.ZERO
	outgoing_slot.hide()
	outgoing_slot.position = Vector2.ZERO


func _panel_size(host: Control) -> Vector2:
	var size: Vector2 = host.size
	if size.x > 0.0 and size.y > 0.0:
		return size
	return host.get_viewport_rect().size


func _layout_slot(slot: Control, panel_size: Vector2) -> void:
	slot.layout_mode = 0
	slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
	slot.anchor_right = 0.0
	slot.anchor_bottom = 0.0
	slot.size = panel_size
