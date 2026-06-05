extends Node

signal completed

var _job: Dictionary = {}
var _transition: Node = null


func start(job: Dictionary, transition: Node) -> void:
	_job = job
	_transition = transition
	_run()


func _run() -> void:
	await WaveCellPlayback.play_cell(
		int(_job["wave_id"]),
		_job["coord"],
		_job["board_view"],
		_job["fx_pool"],
		_job["presentation_state"],
		_job["old_tex"],
		_job["new_tex"],
		_job["new_value"],
		_transition.shake_light_sec,
		_transition.shake_strong_sec,
		_transition.particle_enabled,
		_job.get("reserved_fx")
	)
	completed.emit()
	queue_free()
