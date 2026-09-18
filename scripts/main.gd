class_name Main
extends Node3D
## Race scene bootstrap for DNF. Wires the HUD to the RaceManager singleton and
## starts the race once every child (car, ghost, track, finish line) is ready.
## Runs with PROCESS_MODE_ALWAYS so the restart key still works after a DNF
## pauses the tree; the car and ghost are explicitly PAUSABLE so they freeze.

@export_range(1, 20) var total_laps: int = 3

@onready var _ghost: GhostPlayback = $GhostCar
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	RaceManager.race_started.connect(_on_race_started)
	RaceManager.lap_completed.connect(_on_lap_completed)
	RaceManager.race_won.connect(_on_race_won)
	RaceManager.race_over_dnf.connect(_on_race_over_dnf)
	RaceManager.start_race(total_laps)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ENTER:
		_restart_race()


func _restart_race() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_race_started(_total_laps: int) -> void:
	_update_status()


func _on_lap_completed(_racer: StringName, _lap: int) -> void:
	_update_status()


func _on_race_won() -> void:
	_update_status("YOU SURVIVED — the ghost never caught you.   [Enter] race your new ghost")


func _on_race_over_dnf() -> void:
	_update_status("DNF — the ghost crossed the line ahead of you.   [Enter] retry")


func _update_status(headline: String = "") -> void:
	var lines: PackedStringArray = []
	if not headline.is_empty():
		lines.append(headline)
	lines.append("Laps — You %d/%d  |  Ghost %d/%d" % [
		RaceManager.player_laps, RaceManager.total_laps,
		RaceManager.ghost_laps, RaceManager.total_laps,
	])
	if not _ghost.has_recording():
		lines.append("First run: no ghost yet — this run becomes the Tier 1 ghost.")
	_status_label.text = "\n".join(lines)
