class_name PlayerCar
extends VehicleBody3D
## Core vehicle controller for DNF.
## Attach to a VehicleBody3D with four VehicleWheel3D children: the front pair
## with use_as_steering enabled, the rear pair with use_as_traction enabled.
## The chassis CollisionShape3D must sit above the wheel raycast origins so the
## body never fouls its own ground contact.

@export_group("Engine")
## Maximum engine force applied through the traction wheels (N).
@export var engine_power: float = 1500.0
## Reverse is weaker than forward, like a real gearbox.
@export_range(0.1, 1.0) var reverse_power_ratio: float = 0.6
## Forward speed (m/s) at which the engine stops pushing (~144 km/h). Above
## this the car coasts, so sustained throttle can neither accelerate forever
## nor pitch the chassis over backwards.
@export var top_speed: float = 40.0

@export_group("Steering")
## Maximum steering angle in degrees.
@export var max_steer_angle: float = 32.0
## How fast the wheels turn toward the target angle (higher = snappier).
@export var steer_speed: float = 6.0

@export_group("Braking")
## Brake strength when holding ui_down while moving forward.
@export var brake_force: float = 30.0
## Gentle brake applied when no throttle input, so the car doesn't roll forever.
@export var idle_brake: float = 1.0

## Below this forward speed (m/s), holding ui_down engages reverse instead of braking.
const REVERSE_THRESHOLD: float = 1.0


func _physics_process(delta: float) -> void:
	_apply_steering(delta)
	_apply_throttle_and_brake()


func _apply_steering(delta: float) -> void:
	# get_axis(negative, positive): ui_left is positive because +steering turns left.
	var steer_input := Input.get_axis("ui_right", "ui_left")
	var target_steer := steer_input * deg_to_rad(max_steer_angle)
	steering = lerpf(steering, target_steer, clampf(steer_speed * delta, 0.0, 1.0))


func _apply_throttle_and_brake() -> void:
	var throttle_input := Input.get_axis("ui_down", "ui_up")

	if throttle_input > 0.0:
		# Coast at the cap: cutting engine force (instead of clamping velocity)
		# leaves the solver in charge, so the chassis cannot pitch over from an
		# ever-growing push and speed settles at top_speed on its own.
		# Negative force drives toward -Z: VehicleBody3D's positive engine
		# force propels toward +Z (verified empirically in Godot 4.7).
		engine_force = 0.0 if forward_speed() >= top_speed else -throttle_input * engine_power
		brake = 0.0
	elif throttle_input < 0.0:
		if forward_speed() > REVERSE_THRESHOLD:
			engine_force = 0.0
			brake = -throttle_input * brake_force
		else:
			engine_force = -throttle_input * engine_power * reverse_power_ratio
			brake = 0.0
	else:
		engine_force = 0.0
		brake = idle_brake


## Signed speed along the car's forward direction (-Z), in m/s.
## Positive = driving forward, negative = reversing.
func forward_speed() -> float:
	return linear_velocity.dot(-global_basis.z)


## Convenience for HUD display later.
func speed_kmh() -> float:
	return absf(forward_speed()) * 3.6
