extends CharacterBody3D

@export var initial_speed := 10.0
@export var acceleration := 30.0
@export var max_speed := 80.0
@export var blast_radius := 8.0
@export var blast_force := 20.0
@export var max_damage := 60.0
@export var full_force_distance := 1.5
@export var self_destruct_time := 5.0

var age := 0.0


func _ready() -> void:
	# Only the server simulates rockets; clients receive the synced transform.
	if not multiplayer.is_server():
		set_physics_process(false)


# Call before adding the rocket to the tree.
func launch(shooter: PhysicsBody3D) -> void:
	add_collision_exception_with(shooter)
	velocity = -basis.z * initial_speed


func _physics_process(delta: float) -> void:
	age += delta
	if age >= self_destruct_time:
		destroy()
		return
	velocity = velocity.move_toward(-global_basis.z * max_speed, acceleration * delta)
	var collision := move_and_collide(velocity * delta)
	if collision:
		destroy(collision)


# Override or edit this to change what happens on impact.
func destroy(collision: KinematicCollision3D = null) -> void:
	var point := collision.get_position() if collision else global_position
	explode(point)
	queue_free()


func explode(point: Vector3) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("spawn_explosion"):
		main.spawn_explosion.rpc(point)
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		push_body(hit.collider, point)


func push_body(body: Node3D, point: Vector3) -> void:
	var offset := body.global_position - point
	var distance := maxf(offset.length(), full_force_distance)
	# Inverse square dropoff, capped at full force close to the blast.
	var strength := blast_force * pow(full_force_distance / distance, 2.0)
	var impulse := offset.normalized() * strength
	if body is RigidBody3D:
		body.apply_central_impulse(impulse)
	elif body.has_method("apply_knockback_networked"):
		# Damage first so the knockback already accounts for the lost health.
		if body.has_method("take_damage") and offset.length() <= blast_radius:
			body.take_damage(max_damage * pow(full_force_distance / distance, 2.0))
		body.apply_knockback_networked(impulse)
