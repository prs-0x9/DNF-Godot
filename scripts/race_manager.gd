extends Node
## DNF race manager — register as an Autoload named "RaceManager"
## (Project Settings > Globals > Autoload).
## Tracks lap counts for the player and the ghost and decides the race outcome.
## Finish line crossings are reported by finish_line.gd via body_crossed_finish().

signal race_started(total_laps: int)
signal lap_completed(racer: StringName, lap: int)
## The ghost beat the player. The tree is already paused when this fires.
signal race_over_dnf
## The player finished all laps before the ghost.
signal race_won

const RACER_PLAYER := &"player"
const RACER_GHOST := &"ghost"

## A second crossing within this window is the same physical crossing
## (re-triggered Area3D contact), not a new lap.
const MIN_LAP_TIME := 5.0

@export var total_laps: int = 3
## If true, the ghost merely getting a full lap ahead ends the race early.
## If false (default), DNF only when the ghost finishes the whole race first.
@export var dnf_when_lapped: bool = false

var race_active := false
var player_laps := 0
var ghost_laps := 0

var _last_cross: Dictionary = {}  # racer -> seconds since race start
var _race_time := 0.0


func _ready() -> void:
	# Keep counting and emitting while the tree is paused, so the DNF screen
	# and restart logic still work after we freeze the game.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if race_active and not get_tree().paused:
		_race_time += delta


func start_race(laps: int = total_laps) -> void:
	total_laps = laps
	player_laps = 0
	ghost_laps = 0
	_race_time = 0.0
	_last_cross.clear()
	race_active = true
	get_tree().paused = false
	race_started.emit(total_laps)


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

	# Debounce: an Area3D can report the same crossing more than once.
	if _race_time - _last_cross.get(racer, -MIN_LAP_TIME) < MIN_LAP_TIME:
		return
	_last_cross[racer] = _race_time

	if racer == RACER_PLAYER:
		player_laps += 1
		lap_completed.emit(racer, player_laps)
	else:
		ghost_laps += 1
		lap_completed.emit(racer, ghost_laps)

	_evaluate_race_state()


func _evaluate_race_state() -> void:
	# Player finished every lap first: victory.
	if player_laps >= total_laps:
		race_active = false
		race_won.emit()
		return

	# THE core rule: the ghost finished the race and the player did not. DNF.
	if ghost_laps >= total_laps:
		_trigger_dnf()
		return

	# Optional harsher rule: being a full lap down ends it immediately.
	if dnf_when_lapped and ghost_laps > player_laps + 1:
		_trigger_dnf()


func _trigger_dnf() -> void:
	race_active = false
	get_tree().paused = true
	race_over_dnf.emit()
