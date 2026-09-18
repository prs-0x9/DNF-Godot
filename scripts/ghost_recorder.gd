class_name GhostRecorder
extends Node
## Ghost data serializer for DNF.
## Child of the PlayerCar (VehicleBody3D). Samples the car's global transform on
## a fixed interval in _physics_process and, every time the player completes a
## lap, serializes the run so far to JSON (user://ghost_tier_1.json).
##
## Memory model: samples live in packed structure-of-arrays buffers
## (PackedFloat32Array / PackedVector3Array / PackedVector4Array) — contiguous,
## refcount-free storage with amortized O(1) growth, so recording allocates no
## per-frame heap objects and cannot cause frame-time spikes mid-race. The only
## Dictionary/String work happens once per lap, inside save_ghost_data().

## File format version; GhostPlayback rejects files whose version does not match.
const FORMAT_VERSION: int = 1

## Seconds between samples. 0.1 s = 10 samples/s; playback interpolates between
## them, so a 3-minute race costs ~1800 samples (~58 KB in RAM) instead of
## 10800 full-rate frames.
@export var record_interval: float = 0.1
## Where the ghost run is written.
@export var save_path: String = "user://ghost_tier_1.json"

var _car: VehicleBody3D
var _times: PackedFloat32Array = []
var _positions: PackedVector3Array = []
var _rotations: PackedVector4Array = []  # Quaternion (x, y, z, w) per sample.
var _recording := false
var _elapsed := 0.0
var _time_since_sample := 0.0


func _ready() -> void:
	_car = get_parent() as VehicleBody3D
	if _car == null:
		push_error("GhostRecorder must be a child of a VehicleBody3D.")
		set_physics_process(false)
		return

	# TEMPORARILY COMMENTED OUT FOR TESTING
	# RaceManager.race_started.connect(_on_race_started)
	# RaceManager.lap_completed.connect(_on_lap_completed)
	# RaceManager.race_won.connect(stop_recording)
	# RaceManager.race_over_dnf.connect(stop_recording)
	
	# FORCE RECORDING TO START IMMEDIATELY
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
	_times.clear()
	_positions.clear()
	_rotations.clear()
	_elapsed = 0.0
	_time_since_sample = 0.0
	_recording = true
	_record_frame()  # Capture the starting pose at t = 0.


func stop_recording() -> void:
	_recording = false


func _on_race_started(_total_laps: int) -> void:
	start_recording()


func _on_lap_completed(racer: StringName, _lap: int) -> void:
	if racer == RaceManager.RACER_PLAYER:
		save_ghost_data()


func _record_frame() -> void:
	var quat := _car.global_basis.get_rotation_quaternion()
	_times.append(snappedf(_elapsed, 0.001))
	_positions.append(_car.global_position)
	_rotations.append(Vector4(quat.x, quat.y, quat.z, quat.w))


## Serializes everything recorded so far without stopping the recording, so a
## multi-lap run keeps extending the same ghost file lap by lap.
func save_ghost_data() -> void:
	if _times.is_empty():
		push_warning("GhostRecorder: nothing recorded, not saving.")
		return
	_record_frame()  # Close the run exactly at the moment of the crossing.

	var frames: Array[Dictionary] = []
	for i in _times.size():
		frames.append({
			"t": _times[i],
			"p": [_positions[i].x, _positions[i].y, _positions[i].z],
			"r": [_rotations[i].x, _rotations[i].y, _rotations[i].z, _rotations[i].w],
		})
	var data := {
		"meta": {
			"version": FORMAT_VERSION,
			"interval": record_interval,
			"duration": _times[-1],
			"frame_count": _times.size(),
		},
		"frames": frames,
	}

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("GhostRecorder: could not open %s (error %d)" % [save_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()
	print("Ghost saved: %d frames, %.1f s -> %s" % [
		_times.size(), _times[-1], ProjectSettings.globalize_path(save_path)
	])
	
func _exit_tree() -> void:
	save_ghost_data()
