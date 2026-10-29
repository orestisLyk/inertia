extends RigidBody3D

# A bazooka lying in the level. Walk over it, or pull it to you with the jedi hand, to pick it up.
@export var size := Vector3(0.4, 0.4, 1.0)
@export var ammo := 1
@export var respawn_delay := 5.0
@export var spawn_area_radius := 2.0

var away_time := 0.0

var available := true:
	set(value):
		available = value
		if is_node_ready():
			apply_available()

var home := Transform3D.IDENTITY

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var pickup_area: Area3D = $PickupArea


func _ready() -> void:
	add_to_group("pickups")
	home = transform
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	apply_available()


func apply_available() -> void:
	visible = available
	collision.set_deferred("disabled", not available)
	pickup_area.set_deferred("monitoring", available)


func _physics_process(delta: float) -> void:
	# Only the server simulates; clients just follow the synced transform.
	var should_freeze := not multiplayer.is_server() or not available
	if freeze != should_freeze:
		freeze = should_freeze
	if not multiplayer.is_server() or not available:
		return
	var main := get_tree().current_scene
	if main.has_method("is_out_of_bounds") and main.is_out_of_bounds(global_position):
		reset()
		return
	# Loose outside its spawn area (and not held by the jedi hand) for too long: back to the spawn.
	if global_position.distance_to(home.origin) > spawn_area_radius and not has_meta("held_by"):
		away_time += delta
		if away_time >= respawn_delay:
			reset()
			return
	else:
		away_time = 0.0
	for body in pickup_area.get_overlapping_bodies():
		if body.has_method("grant_bazooka") and collect(body):
			return


# Server only. Returns false if the player can't take it right now.
func collect(player: Node) -> bool:
	if not multiplayer.is_server() or not available or player.is_dead or player.has_bazooka:
		return false
	available = false
	player.grant_bazooka.rpc(ammo)
	return true


# Server only. Puts the bazooka back where the level placed it.
func reset() -> void:
	if not multiplayer.is_server():
		return
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	transform = home
	away_time = 0.0
	available = true
