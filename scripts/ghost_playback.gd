extends CharacterBody3D
## Phase 3 — Ghost playback for DNF.
## Attach to a CharacterBody3D. The body is moved kinematically by setting its
## global_transform directly (move_and_slide is never called), so it can never
## physically push the player. Give it a collision shape on the "ghost" layer
## so the finish line Area3D can still detect it.

signal playback_started
signal playback_finished

@export var ghost_path: String = "user://ghost_run.json"
@export var auto_start: bool = true
## Restart from the first frame when the recording ends (useful for testing).
@export var loop: bool = false

var _times: PackedFloat32Array = []
var _transforms: Array[Transform3D] = []
var _playing := false
var _time := 0.0
## Index of the frame at or before _time. Only ever advances, so per-frame
## lookup is O(1) instead of searching the whole array.
var _frame := 0


func _ready() -> void:
	if not load_ghost_data():
		visible = false
		set_physics_process(false)
		return
	if auto_start:
		start_playback()
	else:
		visible = false


func _physics_process(delta: float) -> void:
	if not _playing:
		return
	_time += delta

	# Advance to the segment containing the current playback time.
	while _frame < _times.size() - 1 and _times[_frame + 1] <= _time:
		_frame += 1

	if _frame >= _times.size() - 1:
		global_transform = _transforms[-1]
		if loop:
			_time = 0.0
			_frame = 0
		else:
			_playing = false
			playback_finished.emit()
		return

	var t0 := _times[_frame]
	var t1 := _times[_frame + 1]
	var weight := 0.0 if t1 <= t0 else clampf((_time - t0) / (t1 - t0), 0.0, 1.0)
	global_transform = _transforms[_frame].interpolate_with(_transforms[_frame + 1], weight)


## Reads and validates the JSON written by ghost_recorder.gd.
## Returns false if there is no usable recording.
func load_ghost_data() -> bool:
	if not FileAccess.file_exists(ghost_path):
		push_warning("GhostPlayback: no ghost file at %s — ghost disabled." % ghost_path)
		return false

	var file := FileAccess.open(ghost_path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null or not data is Dictionary or not data.has("frames"):
		push_error("GhostPlayback: %s is not a valid ghost file." % ghost_path)
		return false
	if data.get("meta", {}).get("version", 0) != 1:
		push_error("GhostPlayback: unsupported ghost format version.")
		return false

	_times.clear()
	_transforms.clear()
	for frame: Dictionary in data["frames"]:
		var p: Array = frame["p"]
		var r: Array = frame["r"]
		var quat := Quaternion(r[0], r[1], r[2], r[3]).normalized()
		_times.append(frame["t"])
		_transforms.append(Transform3D(Basis(quat), Vector3(p[0], p[1], p[2])))

	if _transforms.size() < 2:
		push_warning("GhostPlayback: recording too short to play back.")
		return false
	return true


func start_playback() -> void:
	if _transforms.is_empty():
		return
	_time = 0.0
	_frame = 0
	global_transform = _transforms[0]
	visible = true
	_playing = true
	playback_started.emit()


func stop_playback() -> void:
	_playing = false
