extends Node
## DNF race manager — registered as the Autoload singleton "RaceManager" in
## project.godot. Single owner of race state: lap counts for both racers and
## the race outcome. Finish line crossings are reported by finish_line.gd via
## body_crossed_finish().
##
## THE core rule: whenever the ghost crosses the finish line and its lap count
## exceeds the player's, the player is eliminated on the spot — the SceneTree
## is paused and race_over_dnf is emitted.

signal race_started(total_laps: int)
signal lap_completed(racer: StringName, lap: int)
## The ghost got ahead — player eliminated. The tree is already paused when this fires.
signal race_over_dnf
## The player finished every lap without the ghost ever getting ahead.
signal race_won

const RACER_PLAYER := &"player"
const RACER_GHOST := &"ghost"

## A second crossing within this window is the same physical crossing
## (re-triggered Area3D contact), not a new lap.
const MIN_LAP_TIME: float = 5.0

var total_laps: int = 3
var race_active := false
var player_laps := 0
var ghost_laps := 0

var _last_cross: Dictionary = {}  # racer StringName -> seconds since race start
var _race_time := 0.0


func _ready() -> void:
	# Keep counting and emitting while the tree is paused, so the DNF screen
	# and restart logic still work after the game is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if race_active and not get_tree().paused:
		_race_time += delta


func start_race(laps: int = 3) -> void:
	total_laps = maxi(laps, 1)
	player_laps = 0
	ghost_laps = 0
	_race_time = 0.0
	_last_cross.clear()
	race_active = true
	get_tree().paused = false
	race_started.emit(total_laps)


## Seconds since the green light, excluding paused time.
func race_time() -> float:
	return _race_time


## Called by finish_line.gd for any body that enters the line.
## Racers are identified by node group: "player" or "ghost".
func body_crossed_finish(body: Node3D) -> void:
	if not race_active:
		return
	var racer: StringName
	if body.is_in_group("player"):
		racer = RACER_PLAYER
	elif body.is_in_group("ghost"):
		racer = RACER_GHOST
	else:
		return

	# Debounce: an Area3D can report the same crossing more than once, and the
	# race start counts as a crossing at t = 0 so grid-line jitter is ignored.
	if _race_time - float(_last_cross.get(racer, 0.0)) < MIN_LAP_TIME:
		return
	_last_cross[racer] = _race_time

	if racer == RACER_PLAYER:
		player_laps += 1
		lap_completed.emit(racer, player_laps)
	else:
		ghost_laps += 1
		lap_completed.emit(racer, ghost_laps)

	_evaluate_race_state(racer)


func _evaluate_race_state(racer: StringName) -> void:
	# Player finished every lap without being caught: victory.
	if racer == RACER_PLAYER and player_laps >= total_laps:
		race_active = false
		race_won.emit()
		return

	# THE core rule: the ghost is ahead on laps at a crossing. Instant DNF.
	if racer == RACER_GHOST and ghost_laps > player_laps:
		_trigger_dnf()


func _trigger_dnf() -> void:
	race_active = false
	get_tree().paused = true
	race_over_dnf.emit()
