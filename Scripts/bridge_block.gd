extends "res://Scripts/rigid_block.gd"

# Impulse an explosion must deliver to knock this block loose.
@export var break_threshold := 8.0

var anchored := true


# Only the server simulates; clients just follow the synced transform.
func _physics_process(_delta: float) -> void:
	var should_freeze := not multiplayer.is_server() or anchored
	if freeze != should_freeze:
		freeze = should_freeze


# Called by explosions on the server.
func blast(impulse: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if anchored:
		if impulse.length() < break_threshold:
			return
		anchored = false
		freeze = false
	apply_central_impulse(impulse)
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * impulse.length() * 0.1)
