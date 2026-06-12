extends Node

enum TutorialKind { TAP, CAMERA, TURN_LIMIT, FLAGS }
enum ScenarioPhase { BAD, GOOD, DONE }

const HINT_TAP := "res://assets/gifs/tap.gif"
const HINT_MOVE := "res://assets/gifs/move.gif"
const HINT_SCALE := "res://assets/gifs/scale.gif"

@export var tutorial_kind: TutorialKind = TutorialKind.TAP
@export var level_rules_path: NodePath = NodePath("../LevelRules")
@export var tutorial_prompt_path: NodePath = NodePath("../TutorialPrompt")
@export var cell_tap_hint_path: NodePath = NodePath("../BoardField/TutorialCellTapHint")
@export var camera_controller_path: NodePath = NodePath("../BoardCameraController")

var _stage: int = 0
var _scenario_phase: ScenarioPhase = ScenarioPhase.BAD
var _bad_scenario_completed: bool = false
var _has_seen_loss: bool = false
var _tap_done: bool = false

var _level_rules: Node = null
var _prompt: Node = null
var _cell_tap_hint: Node2D = null
var _camera: Node = null
var _game: Node = null
var _pan_stage_origin: Vector2 = Vector2.ZERO
var _watching_pan_progress: bool = false
var _guided_tap_pending: bool = false

## TAP: клетка, на которую нужно нажать.
@export var tap_hint_coord: Vector2i = Vector2i(1, 0)
## TURN_LIMIT / FLAGS: клетка для плохого сценария.
@export var bad_tap_coord: Vector2i = Vector2i(1, 0)
## TURN_LIMIT / FLAGS: клетка для хорошего сценария.
@export var good_tap_coord: Vector2i = Vector2i(0, 1)
## FLAGS: клетка с флагом.
@export var flag_coord: Vector2i = Vector2i(2, 0)
## CAMERA: смещение камеры (px), после которого открывается этап масштаба.
@export var camera_pan_progress_px: float = 360.0


func _ready() -> void:
	_level_rules = get_node_or_null(level_rules_path)
	_prompt = get_node_or_null(tutorial_prompt_path)
	_cell_tap_hint = get_node_or_null(cell_tap_hint_path) as Node2D
	_camera = get_node_or_null(camera_controller_path)
	_game = get_parent()

	if _game != null:
		if _game.has_signal("move_registered"):
			_game.move_registered.connect(_on_move_registered)
		if _game.has_signal("game_won"):
			_game.game_won.connect(_on_game_won)
		if _game.has_signal("game_lost"):
			_game.game_lost.connect(_on_game_lost)
		if _game.has_signal("session_restart_requested"):
			_game.session_restart_requested.connect(_on_session_restart_requested)

	if _camera != null and _camera.has_signal("zoomed"):
		_camera.zoomed.connect(_on_camera_zoomed)

	set_process(false)
	call_deferred("_start_tutorial")


func filter_cell_tap(coord: Vector2i) -> bool:
	if !_guided_tap_pending:
		return true
	var target: Vector2i = _scenario_tap_coord()
	if target.x < -900:
		return true
	return coord == target


func should_suppress_win_ui() -> bool:
	return false


func handle_restart_request() -> void:
	if tutorial_kind != TutorialKind.TURN_LIMIT and tutorial_kind != TutorialKind.FLAGS:
		return
	if !_bad_scenario_completed:
		return
	if _scenario_phase == ScenarioPhase.BAD:
		_scenario_phase = ScenarioPhase.GOOD
		_stage = 0
		_has_seen_loss = false


func on_session_restarted() -> void:
	if tutorial_kind == TutorialKind.TAP or tutorial_kind == TutorialKind.CAMERA:
		_stage = 0
		_scenario_phase = ScenarioPhase.BAD
		_bad_scenario_completed = false
		_tap_done = false
	elif tutorial_kind == TutorialKind.TURN_LIMIT or tutorial_kind == TutorialKind.FLAGS:
		_stage = 0
		_guided_tap_pending = false
	if _camera != null and _camera.has_method("reset_gesture_hints"):
		_camera.reset_gesture_hints()
	_apply_current_stage()


func _start_tutorial() -> void:
	_stage = 0
	_scenario_phase = ScenarioPhase.BAD
	_bad_scenario_completed = false
	_has_seen_loss = false
	_tap_done = false
	_apply_current_stage()


func _apply_current_stage() -> void:
	match tutorial_kind:
		TutorialKind.TAP:
			_apply_tap_stage()
		TutorialKind.CAMERA:
			_apply_camera_stage()
		TutorialKind.TURN_LIMIT:
			_apply_turn_limit_stage()
		TutorialKind.FLAGS:
			_apply_flags_stage()
	_reapply_level_rules()


func _apply_tap_stage() -> void:
	_set_rules(
		false, false, false,
		true, false, false,
		false, 25
	)
	_show(
		"Нажми на соседнюю клетку, чтобы запустить волну преобразования.",
		HINT_TAP
	)
	_show_cell_tap_hint()


func _apply_camera_stage() -> void:
	match _stage:
		0:
			_set_rules(false, false, false, false, true, false, false, 25)
			_pan_stage_origin = _board_camera_position()
			_watching_pan_progress = true
			set_process(true)
			_show(
				"Свайпни по экрану, чтобы переместить поле.",
				HINT_MOVE
			)
		1:
			_watching_pan_progress = false
			set_process(false)
			_set_rules(false, false, false, false, false, true, false, 25)
			_show(
				"Сведи или разведи пальцы, чтобы изменить масштаб.",
				HINT_SCALE
			)
		_:
			_watching_pan_progress = false
			set_process(false)
			_set_rules(false, false, false, true, true, true, false, 25)
			_show("А теперь закончи уровень.", "")


func _apply_turn_limit_stage() -> void:
	if _scenario_phase == ScenarioPhase.BAD:
		_set_rules(false, true, true, true, true, true, true, 2)
		_show(
			"Сделай ход. У тебя мало ходов — следи за счётчиком сверху.",
			""
		)
	else:
		_set_rules(false, true, true, true, true, true, true, 8)
		_show(
			"Попробуй пройти уровень, планируя ходы заранее.",
			""
		)
	_begin_guided_tap()


func _apply_flags_stage() -> void:
	if _scenario_phase == ScenarioPhase.BAD:
		_set_rules(true, false, true, true, true, true, false, 25)
		_show(
			"Сделай ход, не задевая флаг. Счётчик на флаге уменьшается каждый ход.",
			""
		)
	else:
		_set_rules(true, false, true, true, true, true, false, 25)
		_show(
			"Построй волну так, чтобы она прошла через флаг до обнуления счётчика.",
			""
		)
	_begin_guided_tap()


func _set_rules(
	flags: bool,
	turn_limit: bool,
	show_toolbar: bool,
	taps: bool,
	pan: bool,
	zoom: bool,
	use_random_color: bool,
	turns: int
) -> void:
	if _level_rules == null:
		return
	_level_rules.enable_flags = flags
	_level_rules.enable_turn_limit = turn_limit
	_level_rules.show_turn_toolbar = show_toolbar
	_level_rules.enable_taps = taps
	_level_rules.enable_pan = pan
	_level_rules.enable_zoom = zoom
	_level_rules.max_turns = turns


func _show(text: String, hint: String) -> void:
	if _prompt != null and _prompt.has_method("show_prompt"):
		_prompt.show_prompt(text, hint)


func _show_cell_tap_hint_at(coord: Vector2i) -> void:
	if _cell_tap_hint == null or !_cell_tap_hint.has_method("show_at_cell") or _game == null:
		return
	var board_view: TileMapLayer = _game.get_node_or_null("BoardField/BoardView") as TileMapLayer
	_cell_tap_hint.show_at_cell(board_view, coord)


func _show_cell_tap_hint() -> void:
	if tutorial_kind != TutorialKind.TAP:
		return
	_show_cell_tap_hint_at(tap_hint_coord)


func _begin_guided_tap() -> void:
	if tutorial_kind != TutorialKind.TURN_LIMIT and tutorial_kind != TutorialKind.FLAGS:
		return
	if _scenario_phase == ScenarioPhase.DONE:
		_guided_tap_pending = false
		_hide_cell_tap_hint()
		return
	_guided_tap_pending = true
	_show_cell_tap_hint_at(_scenario_tap_coord())


func _scenario_tap_coord() -> Vector2i:
	match tutorial_kind:
		TutorialKind.TURN_LIMIT, TutorialKind.FLAGS:
			if _scenario_phase == ScenarioPhase.BAD:
				return bad_tap_coord
			if _scenario_phase == ScenarioPhase.GOOD:
				return good_tap_coord
	return Vector2i(-999, -999)


func _hide_cell_tap_hint() -> void:
	if _cell_tap_hint != null and _cell_tap_hint.has_method("hide_hint"):
		_cell_tap_hint.hide_hint()


func _reapply_level_rules() -> void:
	if _game != null and _game.has_method("_apply_level_rules"):
		_game._apply_level_rules()


func _board_camera_position() -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	var board_camera: Camera2D = _camera.get_node_or_null(_camera.camera_path) as Camera2D
	if board_camera == null:
		return Vector2.ZERO
	return board_camera.position


func _on_move_registered(_move_result: Dictionary) -> void:
	if tutorial_kind == TutorialKind.TAP and !_tap_done:
		_tap_done = true
		_hide_cell_tap_hint()
		_show("Отлично! Волна преобразования запущена.", "")
	elif _guided_tap_pending and (
		tutorial_kind == TutorialKind.TURN_LIMIT or tutorial_kind == TutorialKind.FLAGS
	):
		_guided_tap_pending = false
		_hide_cell_tap_hint()
func after_move_flags_updated() -> void:
	if tutorial_kind == TutorialKind.FLAGS and _scenario_phase == ScenarioPhase.BAD:
		_check_flags_bad_scenario_complete()


func _process(_delta: float) -> void:
	if !_watching_pan_progress or tutorial_kind != TutorialKind.CAMERA or _stage != 0:
		return
	if _board_camera_position().distance_to(_pan_stage_origin) < camera_pan_progress_px:
		return
	_watching_pan_progress = false
	set_process(false)
	_stage = 1
	_apply_current_stage()


func _on_camera_zoomed() -> void:
	if tutorial_kind != TutorialKind.CAMERA or _stage != 1:
		return
	_stage = 2
	_apply_current_stage()


func _on_game_won(_move_result: Dictionary) -> void:
	if tutorial_kind == TutorialKind.TURN_LIMIT or tutorial_kind == TutorialKind.FLAGS:
		_scenario_phase = ScenarioPhase.DONE
		_hide_cell_tap_hint()
		_show("Уровень пройден! Можно вернуться в меню.", "")
	elif tutorial_kind == TutorialKind.CAMERA:
		_show("Уровень пройден!", "")


func _on_game_lost() -> void:
	if tutorial_kind != TutorialKind.TURN_LIMIT and tutorial_kind != TutorialKind.FLAGS:
		return
	if _scenario_phase == ScenarioPhase.DONE:
		return
	if _scenario_phase == ScenarioPhase.BAD:
		_has_seen_loss = true
		_bad_scenario_completed = true
		_stage = 1
		if tutorial_kind == TutorialKind.TURN_LIMIT:
			_show(
				"Следи за количеством ходов и за верхним тулбаром. "
				+ "Если уровень зашёл в тупик, начни заново через меню.",
				""
			)
		else:
			_show(
				"Флаги нужно сбивать волной до того, как счётчик станет нулём. "
				+ "Попробуй начать заново через меню.",
				""
			)
	else:
		_show(
			"Ходы закончились. Попробуй начать заново через меню.",
			""
		)
	_open_pause_menu()


func _on_session_restart_requested() -> void:
	pass


func _check_flags_bad_scenario_complete() -> void:
	if _game == null:
		return
	var overlay: Node2D = _game.get_node_or_null("BoardField/CellFlagOverlay") as Node2D
	if overlay == null:
		return
	for child in overlay.get_children():
		if !(child is CellFlagBanner):
			continue
		var flag: CellFlagBanner = child as CellFlagBanner
		if flag.cell_coord != flag_coord:
			continue
		if flag.is_depleted():
			_bad_scenario_completed = true
			_has_seen_loss = true
			_stage = 1
			_show(
				"Флаги нужно сбивать волной до того, как счётчик станет нулём. "
				+ "Попробуй начать заново через меню.",
				""
			)
			_open_pause_menu()
		return


func _open_pause_menu() -> void:
	if _game == null:
		return
	var pause_menu: Node = _game.get_node_or_null("GamePauseMenu")
	if pause_menu != null and pause_menu.has_method("open_menu"):
		pause_menu.call_deferred("open_menu")
