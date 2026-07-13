extends Area3D
## Finish line trigger. Attach to an Area3D with a wide, thin BoxShape3D
## spanning the track. Set its Collision > Mask to include the player's layer
## and the ghost's layer. All lap/DNF logic lives in RaceManager.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	RaceManager.body_crossed_finish(body)
