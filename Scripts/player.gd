extends CharacterBody3D

@export var walk_speed := 5.0
@export var crouch_speed := 2.5
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003
@export var slide_speed := 12.0
@export var slide_duration := 0.8
@export var slide_friction := 6.0
@export var stand_height := 2.0
@export var crouch_height := 1.0
@export var crouch_lerp_speed := 12.0
@export var dash_speed := 18.0
@export var dash_duration := 0.25
@export var dash_cooldown := 0.6
@export var knockback_lock_time := 0.3
@export var ragdoll_min_impulse := 8.0
@export var ragdoll_min_time := 0.4
@export var ragdoll_max_time := 1.5
@export var ragdoll_spin_scale := 0.8
@export var ragdoll_flip_speed := 8.0
@export var air_acceleration := 6.0
@export var wall_jump_velocity := 5.0
@export var wall_jump_push := 6.0
@export var wall_jump_cooldown := 0.3
@export var fire_cooldown := 0.3
@export var max_fire_origin_error := 5.0
@export var punch_radius := 1.0
@export var punch_length := 3.0
@export var punch_force := 15.0
@export var punch_cooldown := 0.5
@export var bump_force := 12.0
@export var max_bump_distance := 6.0
@export var footstep_sound: AudioStream = preload("res://Sound/Effects/footstep_wood_000.ogg")
@export var footstep_interval := 0.4
@export var footstep_min_speed := 1.0

@export var max_health := 100.0
@export var min_mass_ratio := 0.3
var health := max_health
var overhead_back: Sprite3D
var overhead_fill: Sprite3D
var hud_back: ColorRect
var hud_fill: ColorRect
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector3.ZERO
var knockback_timer := 0.0
var is_ragdolling := false
var ragdoll_timer := 0.0
var tumble := Basis.IDENTITY
var tumble_last_position := Vector3.ZERO
var wall_jump_timer := 0.0
var space_was_pressed := false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var gun: Node3D = $Head/Gun
@onready var gun_rest: Transform3D = $Head/Gun.transform
@onready var muzzle: Node3D = $Head/Gun/Muzzle
@onready var collision: CollisionShape3D = $CollisionShape3D
@export var rocket_scene: PackedScene = preload("res://Scenes/rocket.tscn")

var is_crouching := false
var is_sliding := false
var slide_timer := 0.0
var slide_direction := Vector3.ZERO
var head_stand_y := 0.0
var last_fire_msec := 0
var last_punch_msec := 0
var bumped_bodies: Array[Node] = []
var footstep_timer := 0.0
var last_position := Vector3.ZERO
var footstep_player: AudioStreamPlayer3D
var is_dead := false
var awaiting_respawn := false

signal died(player: Node3D)

@onready var body_mesh: MeshInstance3D = $Body


func _enter_tree() -> void:
	# Player nodes are named after their owning peer id.
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int(), true)


func _ready() -> void:
	head_stand_y = head.position.y
	collision.shape = collision.shape.duplicate()
	var is_local := is_multiplayer_authority()
	camera.current = is_local
	body_mesh.visible = not is_local
	last_position = global_position
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.stream = footstep_sound
	footstep_player.unit_size = 4.0
	footstep_player.max_distance = 40.0
	add_child(footstep_player)
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		create_hud_bar()
	else:
		create_overhead_bar()


func health_color() -> Color:
	# Hue 0.33 is green, 0.0 is red.
	return Color.from_hsv(0.33 * clampf(health / max_health, 0.0, 1.0), 0.85, 0.9)


func create_overhead_bar() -> void:
	var image := Image.create(100, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	overhead_back = Sprite3D.new()
	overhead_fill = Sprite3D.new()
	for sprite: Sprite3D in [overhead_back, overhead_fill]:
		sprite.texture = texture
		sprite.pixel_size = 0.012
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.centered = false
		sprite.offset = Vector2(-50, -5)
		sprite.position = Vector3(0, 1.4, 0)
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sprite)
	overhead_back.modulate = Color(0, 0, 0, 0.6)
	overhead_fill.render_priority = 1


func create_hud_bar() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_back = ColorRect.new()
	hud_back.color = Color(0, 0, 0, 0.6)
	hud_back.size = Vector2(240, 22)
	hud_back.position = Vector2(20, -42)
	hud_back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	hud_back.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(hud_back)
	hud_fill = ColorRect.new()
	hud_fill.position = Vector2(3, 3)
	hud_fill.size = Vector2(234, 16)
	hud_back.add_child(hud_fill)


func update_health_bars() -> void:
	var ratio := clampf(health / max_health, 0.0, 1.0)
	if overhead_fill:
		overhead_fill.scale.x = ratio
		overhead_fill.modulate = health_color()
		overhead_back.visible = not is_dead
		overhead_fill.visible = not is_dead
	if hud_fill:
		hud_fill.size.x = 234.0 * ratio
		hud_fill.color = health_color()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				primary_action()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			dash()
		elif event.button_index == MOUSE_BUTTON_XBUTTON1 or event.button_index == MOUSE_BUTTON_XBUTTON2:
			request_punch.rpc_id(1, head.global_position, head.global_basis)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		request_punch.rpc_id(1, head.global_position, head.global_basis)


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and not is_dead:
		simulate(delta)
	update_crouch_visuals(delta)
	update_ragdoll(delta)
	update_footsteps(delta)
	update_health_bars()


# Uses the synced position so remote players' footsteps are heard too.
func update_footsteps(delta: float) -> void:
	var moved := global_position - last_position
	last_position = global_position
	var horizontal_speed := Vector2(moved.x, moved.z).length() / delta
	var grounded := is_on_floor() if is_multiplayer_authority() else absf(moved.y) < 0.02
	if is_dead or is_sliding or not grounded or horizontal_speed < footstep_min_speed:
		footstep_timer = 0.0
		return
	footstep_timer -= delta
	if footstep_timer <= 0.0:
		footstep_timer = footstep_interval
		footstep_player.pitch_scale = randf_range(0.9, 1.1)
		footstep_player.play()

func simulate(delta: float) -> void:
	apply_gravity(delta)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	knockback_timer = maxf(knockback_timer - delta, 0.0)
	if is_ragdolling:
		ragdoll_timer += delta
		if ragdoll_timer >= ragdoll_max_time or (ragdoll_timer >= ragdoll_min_time and is_on_floor()):
			is_ragdolling = false
	wall_jump_timer = maxf(wall_jump_timer - delta, 0.0)
	var space_pressed := Input.is_key_pressed(KEY_SPACE)
	var jumped_from_slide := false
	if space_pressed:
		jumped_from_slide = jump(not space_was_pressed)
	space_was_pressed = space_pressed

	update_crouch_state()
	var dashing := dash_timer > 0.0
	if dashing:
		dash_step(delta)
	elif is_sliding:
		slide(delta)
	elif not jumped_from_slide:
		move(delta)

	move_and_slide()
	if dashing:
		bump_slide_collisions()


# Dashing into a physics body or another player shoves it once per dash.
func bump_slide_collisions() -> void:
	for i in get_slide_collision_count():
		var body := get_slide_collision(i).get_collider() as Node
		if body == null or body in bumped_bodies:
			continue
		if body is RigidBody3D or body.has_method("apply_knockback_networked"):
			bumped_bodies.append(body)
			request_bump.rpc_id(1, body.get_path(), dash_direction)


# Runs on the server only, because rigid bodies are simulated there.
@rpc("any_peer", "call_local", "reliable")
func request_bump(target_path: NodePath, direction: Vector3) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	var target := get_node_or_null(target_path)
	if target == null or target == self or not target is Node3D:
		return
	if (target as Node3D).global_position.distance_to(global_position) > max_bump_distance:
		return
	var impulse := direction.normalized() * bump_force
	if target is RigidBody3D:
		target.apply_central_impulse(impulse)
	elif target.has_method("apply_knockback_networked"):
		target.apply_knockback_networked(impulse)


func look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotate_x(-relative.y * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x, -PI / 2.0, PI / 2.0)


func get_input_direction() -> Vector3:
	var x := int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
	var z := int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
	return (transform.basis * Vector3(x, 0, z)).normalized()


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse
	knockback_timer = knockback_lock_time
	dash_timer = 0.0
	if is_sliding:
		end_slide()
	if impulse.length() >= ragdoll_min_impulse:
		is_ragdolling = true
		ragdoll_timer = 0.0


# Purely visual tumble: the body spins along the travel direction and the camera rolls.
func update_ragdoll(delta: float) -> void:
	var moved := global_position - tumble_last_position
	tumble_last_position = global_position
	var travel := moved / delta if delta > 0.0 else Vector3.ZERO
	if is_ragdolling and not is_dead:
		# Flip around the local X axis, plus a spin along the travel direction.
		var spin := Basis(Vector3.RIGHT, -ragdoll_flip_speed * delta)
		var axis := Vector3.UP.cross(travel)
		if axis.length() > 0.01:
			var local_axis := (global_basis.inverse() * axis).normalized()
			spin = Basis(local_axis, travel.length() * ragdoll_spin_scale * delta) * spin
		tumble = (spin * tumble).orthonormalized()
	else:
		tumble = tumble.slerp(Basis.IDENTITY, minf(delta * 10.0, 1.0))
	var height_scale := (collision.shape as CapsuleShape3D).height / stand_height
	body_mesh.basis = tumble * Basis.from_scale(Vector3(1.0, height_scale, 1.0))
	# The whole player rotates, so the first-person camera and gun tumble around the head too.
	camera.basis = tumble
	gun.transform = Transform3D(tumble * gun_rest.basis, tumble * gun_rest.origin)


func jump(just_pressed: bool = true) -> bool:
	if not just_pressed:
		return false
	if is_on_floor():
		var jumped_from_slide := is_sliding
		velocity.y = jump_velocity
		if jumped_from_slide:
			end_slide()
		return jumped_from_slide
	elif not is_on_floor() and is_on_wall() and wall_jump_timer <= 0.0:
		wall_jump()
	return false


func wall_jump() -> void:
	var normal := get_wall_normal()
	normal.y = 0.0
	velocity.x = normal.x * wall_jump_push
	velocity.z = normal.z * wall_jump_push
	velocity.y = wall_jump_velocity
	wall_jump_timer = wall_jump_cooldown
	dash_timer = 0.0
	if is_sliding:
		end_slide()


func move(delta: float) -> void:
	if knockback_timer > 0.0:
		return
	if not is_on_floor():
		air_control(delta)
		return

	var speed := crouch_speed if is_crouching else walk_speed

	var direction := get_input_direction()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)


func air_control(delta: float) -> void:
	var direction := get_input_direction()
	if direction == Vector3.ZERO:
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed_along := horizontal.dot(direction)
	# Only add speed up to walk_speed along the input direction, never remove existing momentum.
	var room := walk_speed - speed_along
	if room <= 0.0:
		return
	var push := minf(air_acceleration * delta, room)
	velocity.x += direction.x * push
	velocity.z += direction.z * push


func update_crouch_state() -> void:
	var wants_crouch := Input.is_key_pressed(KEY_C)
	if wants_crouch and not is_crouching:
		crouch()
	elif not wants_crouch and (is_crouching or is_sliding):
		stand()


func crouch() -> void:
	# Crouching while moving on the ground starts a slide.
	if is_on_floor() and get_input_direction() != Vector3.ZERO:
		start_slide()
	is_crouching = true


func stand() -> void:
	is_crouching = false
	if is_sliding:
		end_slide()


func start_slide() -> void:
	is_sliding = true
	slide_timer = slide_duration
	slide_direction = get_input_direction()


func end_slide() -> void:
	is_sliding = false


func slide(delta: float) -> void:
	slide_timer -= delta
	var t := clampf(slide_timer / slide_duration, 0.0, 1.0)
	var speed := lerpf(crouch_speed, slide_speed, t)
	velocity.x = slide_direction.x * speed
	velocity.z = slide_direction.z * speed
	if slide_timer <= 0.0 or not is_on_floor():
		end_slide()


func update_crouch_visuals(delta: float) -> void:
	var shape := collision.shape as CapsuleShape3D
	var target_height := crouch_height if is_crouching else stand_height
	shape.height = lerpf(shape.height, target_height, crouch_lerp_speed * delta)
	# Keep the capsule's bottom on the ground while its height changes.
	collision.position.y = (shape.height - stand_height) / 2.0
	var head_target := head_stand_y - (stand_height - target_height) / 2.0
	head.position.y = lerpf(head.position.y, head_target, crouch_lerp_speed * delta)
	body_mesh.position.y = collision.position.y


func dash() -> void:
	var direction := get_input_direction()
	if direction == Vector3.ZERO or dash_cooldown_timer > 0.0 or dash_timer > 0.0:
		return
	dash_direction = direction
	bumped_bodies.clear()
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown


func dash_step(delta: float) -> void:
	dash_timer = maxf(dash_timer - delta, 0.0)
	# Burst decays toward walk speed; airborne, the remainder is kept as momentum.
	var speed := lerpf(walk_speed, dash_speed, dash_timer / dash_duration)
	velocity.x = dash_direction.x * speed
	velocity.z = dash_direction.z * speed


func take_damage(amount: float) -> void:
	if multiplayer.is_server() and not is_dead:
		sync_health.rpc(maxf(health - amount, 0.0))


@rpc("any_peer", "call_local", "reliable")
func sync_health(value: float) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	health = value


# Less health means less mass, so the same impulse pushes further.
func get_mass_ratio() -> float:
	return lerpf(min_mass_ratio, 1.0, health / max_health)


# Server-side kill. Rockets and future traps call this.
func die() -> void:
	if not multiplayer.is_server() or is_dead:
		return
	set_dead.rpc(true)
	died.emit(self)


@rpc("any_peer", "call_local", "reliable")
func set_dead(value: bool) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	is_dead = value
	is_ragdolling = false
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", value)
	if value:
		end_slide()
		dash_timer = 0.0
	elif is_multiplayer_authority():
		is_crouching = false


# Server tells the owning client where to respawn, since clients own their position.
@rpc("any_peer", "call_local", "reliable")
func respawn(spawn_position: Vector3) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	position = spawn_position
	health = max_health
	knockback_timer = 0.0
	set_dead(false)
	if multiplayer.is_server() and is_multiplayer_authority():
		awaiting_respawn = false
	elif is_multiplayer_authority():
		confirm_respawn.rpc_id(1)


# The owner confirms it has moved, so the server stops trusting its old synced position.
@rpc("any_peer", "call_remote", "reliable")
func confirm_respawn() -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	# Let in-flight position packets from before the respawn drain first.
	await get_tree().create_timer(0.5).timeout
	awaiting_respawn = false


func primary_action() -> void:
	print("Left mouse button clicked")
	request_fire.rpc_id(1, muzzle.global_position, head.global_basis)


# Runs on the server only; clients ask, the server spawns the rocket.
@rpc("any_peer", "call_local", "reliable")
func request_fire(origin: Vector3, aim: Basis) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	var now := Time.get_ticks_msec()
	if now - last_fire_msec < fire_cooldown * 1000.0:
		return
	last_fire_msec = now
	if origin.distance_to(muzzle.global_position) > max_fire_origin_error:
		origin = muzzle.global_position
	spawn_rocket(origin, aim.orthonormalized())


# Runs on the server only; clients ask, the server pushes everything in the punch cylinder.
@rpc("any_peer", "call_local", "reliable")
func request_punch(origin: Vector3, aim: Basis) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	var now := Time.get_ticks_msec()
	if now - last_punch_msec < punch_cooldown * 1000.0:
		return
	last_punch_msec = now
	if origin.distance_to(head.global_position) > max_fire_origin_error:
		origin = head.global_position
	punch(origin, aim.orthonormalized())


func punch(origin: Vector3, aim: Basis) -> void:
	var forward := -aim.z
	var cylinder := CylinderShape3D.new()
	cylinder.radius = punch_radius
	cylinder.height = punch_length
	# Cylinders stand along Y, so tip it to lie along the aim direction.
	var shape_basis := aim * Basis(Vector3.RIGHT, PI / 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = cylinder
	query.transform = Transform3D(shape_basis, origin + forward * punch_length / 2.0)
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body: Node3D = hit.collider
		var impulse := forward * punch_force
		if body is RigidBody3D:
			body.apply_central_impulse(impulse)
		elif body.has_method("apply_knockback_networked"):
			body.apply_knockback_networked(impulse)


func spawn_rocket(origin: Vector3, aim: Basis) -> void:
	var rocket := rocket_scene.instantiate() as Node3D
	rocket.transform = Transform3D(aim, origin)
	rocket.launch(self)
	get_node("../../Rockets").add_child(rocket, true)


# Players simulate their own velocity, so the server forwards blast impulses to the owner.
func apply_knockback_networked(impulse: Vector3) -> void:
	impulse /= get_mass_ratio()
	var owner_id := get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id():
		apply_knockback(impulse)
	else:
		receive_knockback.rpc_id(owner_id, impulse)


@rpc("any_peer", "call_remote", "reliable")
func receive_knockback(impulse: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1 and not is_dead:
		apply_knockback(impulse)
