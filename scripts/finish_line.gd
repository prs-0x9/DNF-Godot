class_name FinishLine
extends Area3D
## Finish line trigger. Attach to an Area3D with a wide, thin BoxShape3D
## spanning the track. Its Collision > Mask must include the player's layer
## and the ghost's layer. This node only reports crossings; all lap counting
## and the DNF ruling live in the RaceManager singleton.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	RaceManager.body_crossed_finish(body)
