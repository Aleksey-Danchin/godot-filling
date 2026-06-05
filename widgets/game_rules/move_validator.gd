extends Node

const OK := "OK"
const GAME_OVER := "GAME_OVER"
const NOT_EXPANDING_MOVE := "NOT_EXPANDING_MOVE"
const NO_MOVES := "NO_MOVES"
const INVALID_CELL := "INVALID_CELL"
const NO_OP_MOVE := "NO_OP_MOVE"


func validate(board_coord: Vector2i, next_value: int, board_model: Node, session: Node) -> Dictionary:
	if !session.is_active:
		return {"ok": false, "reason": GAME_OVER}

	if !session.can_continue():
		return {"ok": false, "reason": NO_MOVES}

	if !board_model.has_cell_coord(board_coord):
		return {"ok": false, "reason": INVALID_CELL}

	if board_model.get_value(board_model.start_coord) == next_value:
		return {"ok": false, "reason": NO_OP_MOVE}

	if board_model.has_method("is_move_value_available"):
		if !board_model.is_move_value_available(next_value):
			return {"ok": false, "reason": NOT_EXPANDING_MOVE}

	return {"ok": true, "reason": OK}
