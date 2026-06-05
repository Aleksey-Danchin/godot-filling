extends Node

const WAVE_JOB_RUNNER_SCRIPT := preload("res://widgets/game_transition/wave_job_runner.gd")
const _EPS := 0.0001
const _INF := 1.0e20
const _NEG_INF := -1.0e20

signal active_waves_changed(active_count: int)
signal wave_playback_finished(move_result: Dictionary, move_generation: int)

@export_range(0.0, 1.0, 0.01) var wave_delay_sec: float = 0.12
@export_range(0.0, 1.0, 0.01) var shake_light_sec: float = 0.15
@export_range(0.0, 1.0, 0.01) var shake_strong_sec: float = 0.22
@export var particle_enabled: bool = true

var _active_waves: int = 0
var _scheduled_jobs: Array[Dictionary] = []
var _in_flight_jobs: int = 0
var _max_parallel_jobs: int = 64
var _next_wave_id: int = 0
var _schedule_seq: int = 0
var _layer_manager: Node = null
var _presentation_state: Node = null
var _pending_waves: Array[Dictionary] = []
var _active_wave_order: Array[int] = []
var _wave_rr_index: int = 0
## wave_id -> { move_result, move_generation, remaining, root_started, root_started_at, fx_layer }
var _wave_state: Dictionary = {}


func _ready() -> void:
	set_process(true)


func get_active_wave_count() -> int:
	return _active_waves


func get_pending_wave_count() -> int:
	return _pending_waves.size()


func get_activity_count() -> int:
	return _active_waves + _pending_waves.size()


func stop_all() -> void:
	_pending_waves.clear()
	_scheduled_jobs.clear()
	_wave_state.clear()
	_active_wave_order.clear()
	_wave_rr_index = 0
	_in_flight_jobs = 0
	if _active_waves > 0:
		_active_waves = 0
	if _layer_manager != null and _layer_manager.has_method("stop_all"):
		_layer_manager.stop_all()
	if _presentation_state != null and _presentation_state.has_method("clear"):
		_presentation_state.clear()
	_emit_activity_changed()


func play_wave(
	move_result: Dictionary,
	board_view: TileMapLayer,
	layer_manager: Node,
	presentation_state: Node,
	move_generation: int = 0
) -> void:
	_layer_manager = layer_manager
	_presentation_state = presentation_state
	_pending_waves.append({
		"move_result": move_result,
		"board_view": board_view,
		"presentation_state": presentation_state,
		"move_generation": move_generation,
	})
	_emit_activity_changed()
	_try_start_pending_waves()


func _try_start_pending_waves() -> void:
	if _layer_manager == null:
		return

	while !_pending_waves.is_empty():
		var wave_id: int = _next_wave_id
		var fx_layer: Node = _layer_manager.try_claim_layer(wave_id)
		if fx_layer == null:
			break

		_next_wave_id += 1
		var entry: Dictionary = _pending_waves.pop_front()
		_start_wave(wave_id, fx_layer, entry)


func _start_wave(wave_id: int, fx_layer: Node, entry: Dictionary) -> void:
	var move_result: Dictionary = entry["move_result"]
	var board_view: TileMapLayer = entry["board_view"]
	var move_generation: int = entry["move_generation"]
	var fx_pool: Node = fx_layer.get_pool() if fx_layer.has_method("get_pool") else null

	_begin_wave()
	_sync_capacity_from_pool(fx_pool)

	var wave_layers: Array = move_result.get("wave_layers", [])
	if wave_layers.is_empty():
		_complete_wave(wave_id)
		return

	var old_value: int = move_result.get("old_value", -1)
	var new_value: int = move_result.get("new_value", -1)
	var old_tex: Texture2D = board_view.get_texture_for_value(old_value)
	var new_tex: Texture2D = board_view.get_texture_for_value(new_value)

	var presentation_state: Node = entry.get("presentation_state", _presentation_state)

	if old_tex == null or new_tex == null:
		var changed_cells: Array[Vector2i] = move_result.get("changed_cells", [])
		for coord_variant in changed_cells:
			var coord: Vector2i = coord_variant
			if presentation_state != null and presentation_state.has_method("request_cell_commit"):
				presentation_state.request_cell_commit(wave_id, coord, new_value, board_view)
			else:
				board_view.render_coord_value(coord, new_value)
		_complete_wave(wave_id)
		return

	var remaining: Array[int] = [0]
	_wave_state[wave_id] = {
		"move_result": move_result,
		"move_generation": move_generation,
		"remaining": remaining,
		"root_started": false,
		"root_started_at": -1.0,
		"fx_layer": fx_layer,
	}
	_active_wave_order.append(wave_id)
	var wave_root: Vector2i = move_result.get("wave_root", Vector2i.ZERO)
	var wave_cells: Array[Vector2i] = []

	for wave_index in range(wave_layers.size()):
		var layer_cells: Array = wave_layers[wave_index]
		if layer_cells.is_empty():
			continue

		var order_in_layer: int = 0
		for coord_variant in layer_cells:
			var coord: Vector2i = coord_variant
			wave_cells.append(coord)
			var dist_from_root: int = _manhattan_dist(coord, wave_root)
			_scheduled_jobs.append({
				"wave_id": wave_id,
				"ring": wave_index,
				"order_in_layer": order_in_layer,
				"dist_from_root": dist_from_root,
				"schedule_seq": _schedule_seq,
				"coord": coord,
				"board_view": board_view,
				"presentation_state": presentation_state,
				"fx_layer": fx_layer,
				"fx_pool": fx_pool,
				"old_tex": old_tex,
				"new_tex": new_tex,
				"new_value": new_value,
			})
			_schedule_seq += 1
			order_in_layer += 1
			remaining[0] += 1

	if presentation_state != null and presentation_state.has_method("register_wave_cells"):
		presentation_state.register_wave_cells(wave_id, wave_cells, new_value)

	if remaining[0] == 0:
		_complete_wave(wave_id)


func _process(_delta: float) -> void:
	_tick_scheduler()


func _tick_scheduler() -> void:
	if _scheduled_jobs.is_empty() and _in_flight_jobs == 0:
		return

	_drop_stale_jobs()
	_sort_scheduled_jobs()

	while _in_flight_jobs < _max_parallel_jobs and !_scheduled_jobs.is_empty():
		var now_sec: float = _game_time_sec()
		var launch_index: int = _pick_launchable_job_index(now_sec)
		if launch_index < 0:
			break

		var job: Dictionary = _scheduled_jobs[launch_index]
		var fx_pool: Node = job.get("fx_pool")
		var fx_layer: Node2D = job.get("fx_layer")
		var reserved_fx: Node2D = null
		if fx_pool != null and fx_pool.has_method("reserve_slot_for_layer"):
			reserved_fx = fx_pool.reserve_slot_for_layer(fx_layer)
			if reserved_fx == null:
				break
		job["reserved_fx"] = reserved_fx
		_scheduled_jobs.remove_at(launch_index)
		_launch_job(job, now_sec)


func _drop_stale_jobs() -> void:
	var i: int = 0
	while i < _scheduled_jobs.size():
		var wave_id: int = _scheduled_jobs[i]["wave_id"]
		if !_wave_state.has(wave_id):
			_scheduled_jobs.remove_at(i)
		else:
			i += 1


func _pick_launchable_job_index(now_sec: float) -> int:
	if _active_wave_order.is_empty():
		return _find_first_launchable_job_index(now_sec)

	var wave_count: int = _active_wave_order.size()
	for _i in range(wave_count):
		if _active_wave_order.is_empty():
			return -1
		if _wave_rr_index >= _active_wave_order.size():
			_wave_rr_index = 0

		var wave_id: int = _active_wave_order[_wave_rr_index]
		_wave_rr_index = (_wave_rr_index + 1) % _active_wave_order.size()

		var idx: int = _find_launchable_job_for_wave(wave_id, now_sec)
		if idx >= 0:
			return idx

	return _find_first_launchable_job_index(now_sec)


func _find_launchable_job_for_wave(wave_id: int, now_sec: float) -> int:
	for i in range(_scheduled_jobs.size()):
		var job: Dictionary = _scheduled_jobs[i]
		if int(job["wave_id"]) != wave_id:
			continue
		if _is_job_launchable(job, now_sec):
			return i
	return -1


func _find_first_launchable_job_index(now_sec: float) -> int:
	for i in range(_scheduled_jobs.size()):
		if _is_job_launchable(_scheduled_jobs[i], now_sec):
			return i
	return -1


func _is_job_launchable(job: Dictionary, now_sec: float) -> bool:
	var wave_id: int = job["wave_id"]
	if !_wave_state.has(wave_id):
		return false

	var due_at: float = _job_due_at(job)
	if due_at > now_sec + _EPS:
		return false

	var fx_pool: Node = job.get("fx_pool")
	var fx_layer: Node2D = job.get("fx_layer")
	if fx_pool != null and fx_pool.has_method("reserve_slot_for_layer"):
		if fx_pool.count_idle_slots() <= 0:
			return false
		if fx_pool.owner_layer != null and fx_layer != fx_pool.owner_layer:
			return false

	return true


func _sort_scheduled_jobs() -> void:
	_scheduled_jobs.sort_custom(_compare_jobs)


func _compare_jobs(a: Dictionary, b: Dictionary) -> bool:
	var due_a: float = _job_due_at(a)
	var due_b: float = _job_due_at(b)
	if due_a != due_b:
		return due_a < due_b
	if a["wave_id"] != b["wave_id"]:
		return a["wave_id"] < b["wave_id"]
	if a["ring"] != b["ring"]:
		return a["ring"] < b["ring"]
	if a["order_in_layer"] != b["order_in_layer"]:
		return a["order_in_layer"] < b["order_in_layer"]
	if a["dist_from_root"] != b["dist_from_root"]:
		return a["dist_from_root"] < b["dist_from_root"]
	return a["schedule_seq"] < b["schedule_seq"]


func _job_due_at(job: Dictionary) -> float:
	var wave_id: int = job["wave_id"]
	if !_wave_state.has(wave_id):
		return _NEG_INF

	var ring: int = job["ring"]
	if ring <= 0:
		return _NEG_INF

	var state: Dictionary = _wave_state[wave_id]
	if !state["root_started"]:
		return _INF

	return float(state["root_started_at"]) + float(ring) * wave_delay_sec


func _launch_job(job: Dictionary, now_sec: float) -> void:
	var wave_id: int = job["wave_id"]
	if _wave_state.has(wave_id):
		var state: Dictionary = _wave_state[wave_id]
		if !state["root_started"] and int(job["ring"]) == 0:
			state["root_started"] = true
			state["root_started_at"] = now_sec

	_in_flight_jobs += 1

	var runner: Node = Node.new()
	runner.set_script(WAVE_JOB_RUNNER_SCRIPT)
	add_child(runner)
	runner.completed.connect(_on_job_runner_completed.bind(job, runner), CONNECT_ONE_SHOT)
	runner.start(job, self)


func _on_job_runner_completed(job: Dictionary, _runner: Node) -> void:
	_in_flight_jobs -= 1

	var wave_id: int = job["wave_id"]
	if !_wave_state.has(wave_id):
		return

	var remaining: Array = _wave_state[wave_id]["remaining"]
	remaining[0] -= 1
	if remaining[0] <= 0:
		_complete_wave(wave_id)


func _complete_wave(wave_id: int) -> void:
	if !_wave_state.has(wave_id):
		return

	var state: Dictionary = _wave_state[wave_id]
	var move_result: Dictionary = state["move_result"]
	var move_generation: int = state["move_generation"]
	_wave_state.erase(wave_id)
	_active_wave_order.erase(wave_id)
	if _active_wave_order.is_empty():
		_wave_rr_index = 0
	elif _wave_rr_index >= _active_wave_order.size():
		_wave_rr_index = 0

	if _layer_manager != null and _layer_manager.has_method("release_layer"):
		_layer_manager.release_layer(wave_id)

	_end_wave()
	wave_playback_finished.emit(move_result, move_generation)
	_emit_activity_changed()
	_try_start_pending_waves()


func _manhattan_dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _game_time_sec() -> float:
	return Time.get_ticks_msec() / 1000.0


func _sync_capacity_from_pool(_fx_pool: Node) -> void:
	if _layer_manager != null and _layer_manager.has_method("get_total_pool_capacity"):
		var total_cap: int = _layer_manager.get_total_pool_capacity()
		if total_cap > 0:
			_max_parallel_jobs = total_cap
			return

	if _fx_pool == null:
		return

	var cap_variant: Variant = _fx_pool.get("pool_size")
	if typeof(cap_variant) == TYPE_INT:
		var cap: int = int(cap_variant)
		if cap > 0:
			_max_parallel_jobs = cap


func _begin_wave() -> void:
	_active_waves += 1
	_emit_activity_changed()


func _end_wave() -> void:
	_active_waves = maxi(0, _active_waves - 1)
	_emit_activity_changed()


func _emit_activity_changed() -> void:
	active_waves_changed.emit(get_activity_count())
