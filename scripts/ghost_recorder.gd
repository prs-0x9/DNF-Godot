extends Node
## Phase 2 — Ghost recorder for DNF.
## Attach to a plain Node that is a child of the PlayerCar (VehicleBody3D).
## Records the parent's transform at fixed intervals; press R to save (temporary
## test binding — the finish line will call save_ghost_data() in Phase 4).

## File version, bumped if the format ever changes so old ghosts can be rejected.
const FORMAT_VERSION := 1

## Seconds between samples. 0.1 s = 10 samples/sec; playback interpolates between them.
@export var record_interval: float = 0.1
## Where the ghost run is written.
@export var save_path: String = "user://ghost_run.json"
## Start recording automatically when the scene loads.
@export var auto_start: bool = true

var _car: VehicleBody3D
var _frames: Array[Dictionary] = []
var _recording := false
var _elapsed := 0.0
var _time_since_sample := 0.0


func _ready() -> void:
	_car = get_parent() as VehicleBody3D
	if _car == null:
		push_error("GhostRecorder must be a child of a VehicleBody3D.")
		set_physics_process(false)
		return

	# When the RaceManager autoload is present, follow the race lifecycle:
	# record from the green light, and a winning run becomes the next ghost.
	var race_manager := get_node_or_null("/root/RaceManager")
	if race_manager != null:
		race_manager.race_started.connect(func(_laps: int) -> void: start_recording())
		race_manager.race_won.connect(save_ghost_data)
		race_manager.race_over_dnf.connect(stop_recording)
	elif auto_start:
		start_recording()


func _physics_process(delta: float) -> void:
	if not _recording:
		return
	_elapsed += delta
	_time_since_sample += delta
	if _time_since_sample >= record_interval:
		_time_since_sample -= record_interval
		_record_frame()


func start_recording() -> void:
	_frames.clear()
	_elapsed = 0.0
	_time_since_sample = 0.0
	_recording = true
	_record_frame()  # Capture the starting pose at t = 0.


func stop_recording() -> void:
	_recording = false


func _record_frame() -> void:
	var quat := _car.global_basis.get_rotation_quaternion()
	_frames.append({
		"t": snappedf(_elapsed, 0.001),
		"p": [_car.global_position.x, _car.global_position.y, _car.global_position.z],
		"r": [quat.x, quat.y, quat.z, quat.w],
	})


func save_ghost_data() -> void:
	if _frames.is_empty():
		push_warning("GhostRecorder: nothing recorded, not saving.")
		return
	stop_recording()

	var data := {
		"meta": {
			"version": FORMAT_VERSION,
			"interval": record_interval,
			"duration": _frames[-1]["t"],
			"frame_count": _frames.size(),
		},
		"frames": _frames,
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("GhostRecorder: could not open %s (error %d)" % [save_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()
	print("Ghost saved: %d frames, %.1f s -> %s" % [
		_frames.size(), _frames[-1]["t"], ProjectSettings.globalize_path(save_path)
	])


## Temporary test binding: press R to stop recording and save.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_R:
		save_ghost_data()
