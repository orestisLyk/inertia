extends CharacterBody3D

@export var initial_speed := 10.0
@export var acceleration := 30.0
@export var max_speed := 80.0
@export var blast_radius := 8.0
@export var blast_force := 20.0
@export var full_force_distance := 1.5
@export var ghost_lifetime := 6.0

# Synced once at spawn so the shooter's client knows which replica is theirs.
var shooter_id := 0
# A client-side stand-in shown to the shooter immediately, before the server's rocket arrives.
var is_ghost := false
var ghost_age := 0.0


func _ready() -> void:
	if is_ghost:
		$MultiplayerSynchronizer.queue_free()
		$CollisionShape3D.queue_free()
		add_to_group("ghost_rockets")
		return
	# Only the server simulates rockets; clients receive the synced transform.
	if not multiplayer.is_server():
		set_physics_process(false)
		# The shooter already sees the ghost, so hide their delayed replica.
		if shooter_id == multiplayer.get_unique_id():
			hide()


func _exit_tree() -> void:
	if is_ghost or multiplayer.is_server() or shooter_id != multiplayer.get_unique_id():
		return
	var ghosts := get_tree().get_nodes_in_group("ghost_rockets")
	if not ghosts.is_empty():
		ghosts[0].queue_free()


# Call before adding the rocket to the tree.
func launch(shooter: PhysicsBody3D) -> void:
	add_collision_exception_with(shooter)
	shooter_id = shooter.get_multiplayer_authority()
	velocity = -basis.z * initial_speed


func _physics_process(delta: float) -> void:
	if is_ghost:
		ghost_step(delta)
		return
	velocity = velocity.move_toward(-global_basis.z * max_speed, acceleration * delta)
	var collision := move_and_collide(velocity * delta)
	if collision:
		destroy(collision)


func ghost_step(delta: float) -> void:
	if velocity == Vector3.ZERO:
		velocity = -global_basis.z * initial_speed
	velocity = velocity.move_toward(-global_basis.z * max_speed, acceleration * delta)
	global_position += velocity * delta
	ghost_age += delta
	if ghost_age > ghost_lifetime:
		queue_free()


# Override or edit this to change what happens on impact.
func destroy(collision: KinematicCollision3D = null) -> void:
	var point := collision.get_position() if collision else global_position
	var victim := collision.get_collider() if collision else null
	if victim and victim.has_method("die"):
		victim.die()
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
		body.apply_knockback_networked(impulse)
