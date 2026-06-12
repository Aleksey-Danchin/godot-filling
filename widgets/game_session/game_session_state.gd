extends Node

signal state_changed()

@export_range(1, 999) var max_turns: int = 25

var turns: int = 0
var is_active: bool = true
var is_paused: bool = false
var is_animating: bool = false
var turn_limit_enabled: bool = true
var history: Array[Dictionary] = []


func configure_turn_limit(enabled: bool, turn_limit: int = max_turns) -> void:
	turn_limit_enabled = enabled
	max_turns = max(1, turn_limit)


func start_new_game(turn_limit: int = max_turns) -> void:
	if turn_limit_enabled:
		max_turns = max(1, turn_limit)
	turns = 0
	is_active = true
	is_paused = false
	is_animating = false
	history.clear()
	state_changed.emit()


func register_move(move_data: Dictionary) -> void:
	turns += 1
	history.append(move_data)
	state_changed.emit()


func can_continue() -> bool:
	if !is_active or is_paused:
		return false
	if !turn_limit_enabled:
		return true
	return turns < max_turns


func set_animating(value: bool) -> void:
	is_animating = value
	state_changed.emit()


func finish_game() -> void:
	is_active = false
	state_changed.emit()
