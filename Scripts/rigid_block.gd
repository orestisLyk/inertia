extends RigidBody3D

@export var size := Vector3.ONE
@export var density := 1.0
@export var bump_min_speed := 6.0
@export var bump_factor := 1.0
@export var bump_cooldown := 0.6

var bumped_at := {}

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	add_to_group("rigid_blocks")
	# Rigid bodies can't be scaled, so each block builds its own shape and mesh at its size.
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	var box_mesh := mesh_instance.mesh.duplicate() as BoxMesh
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mass = size.x * size.y * size.z * density
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 8


# Server only. A fast-moving body shoves any player it hits, like a dash bump.
func bump_players() -> void:
	if freeze or not multiplayer.is_server():
		return
	var speed := linear_velocity.length()
	if speed < bump_min_speed:
		return
	var now := Time.get_ticks_msec()
	for body in get_colliding_bodies():
		if not body.has_method("apply_knockback_networked") or body.get("is_dead"):
			continue
		if body == get_meta("held_by", null):
			continue
		if now - bumped_at.get(body, -100000) < bump_cooldown * 1000.0:
			continue
		bumped_at[body] = now
		body.apply_knockback_networked(linear_velocity.normalized() * speed * bump_factor)


func _physics_process(_delta: float) -> void:
	# Only the server simulates; clients just follow the synced transform.
	var should_freeze := not multiplayer.is_server()
	if freeze != should_freeze:
		freeze = should_freeze
	bump_players()


@rpc("authority", "call_local", "reliable")
func despawn() -> void:
	queue_free()
