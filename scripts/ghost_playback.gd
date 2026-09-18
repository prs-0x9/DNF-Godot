class_name GhostPlayback
extends CharacterBody3D
## Ghost playback AI for DNF.
## Attach to a CharacterBody3D. The body is moved kinematically by writing its
## global_transform directly (move_and_slide is never called), so it can never
## physically shove the player. Keep its collision layer off the player's mask;
## the layer only exists so the finish line Area3D can detect crossings.

signal playback_started
signal playback_finished

@export var ghost_path: String = "user://ghost_tier_1.json"
## Restart from the first frame when the recording ends (useful for testing).
@export var loop: bool = false

var _times: PackedFloat32Array = []
var _transforms: Array[Transform3D] = []
var _playing := false
var _time := 0.0
## Index of the frame at or before _time. Only ever advances, so per-frame
## lookup is O(1) amortized instead of a search over the whole array.
var _frame := 0


func _ready() -> void:
	visible = false
	if not load_ghost_data():
		set_physics_process(false)
		return

	# Named methods so the connections die with this node on scene reload;
	# the RaceManager autoload persists across reloads.
	RaceManager.race_started.connect(_on_race_started)
	RaceManager.race_won.connect(stop_playback)
	RaceManager.race_over_dnf.connect(stop_playback)


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


## Reads and validates the JSON written by GhostRecorder.
## Returns false if there is no usable recording.
func load_ghost_data() -> bool:
	if not FileAccess.file_exists(ghost_path):
		push_warning("GhostPlayback: no ghost file at %s — ghost disabled." % ghost_path)
		return false

	var file := FileAccess.open(ghost_path, FileAccess.READ)
	if file == null:
		push_error("GhostPlayback: could not open %s (error %d)" % [ghost_path, FileAccess.get_open_error()])
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null or not data is Dictionary or not data.has("frames"):
		push_error("GhostPlayback: %s is not a valid ghost file." % ghost_path)
		return false
	if data.get("meta", {}).get("version", 0) != GhostRecorder.FORMAT_VERSION:
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


## True once a valid recording is loaded and ready to race.
func has_recording() -> bool:
	return _transforms.size() >= 2


func start_playback() -> void:
	if not has_recording():
		return
	_time = 0.0
	_frame = 0
	global_transform = _transforms[0]
	visible = true
	_playing = true
	playback_started.emit()


func stop_playback() -> void:
	_playing = false


func _on_race_started(_total_laps: int) -> void:
	start_playback()
