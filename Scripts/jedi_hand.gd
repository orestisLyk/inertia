extends "res://Scripts/weapon.gd"

@export var grab_range := 20.0
@export var grab_tolerance := 5.0
@export var collect_distance := 0.6
@export var hover_distance := 2.5
@export var hover_side_offset := 1.5
@export var pull_stiffness := 8.0
@export var pull_max_speed := 25.0
@export var push_range := 10.0
@export var push_width := 4.0
@export var push_min_speed := 10.0
@export var push_max_speed := 40.0
@export var push_max_charge := 1.5
@export var push_cooldown := 0.5
@export var shake_amount := 0.02
@export var tremble_speed := 6.0
@export var tremble_spin := 4.0
@export var push_lunge := 0.4
@export var push_anim_time := 0.25

var model: Node3D
var pulling := false
var charging := false
var charge := 0.0
var hud_layer: CanvasLayer
var hud_fill: ColorRect
var push_t := 1.0
var held_body: RigidBody3D
var selected: RigidBody3D
var outline_material: ShaderMaterial
var held_gravity := 1.0
var last_push_msec := 0


func _ready() -> void:
	outline_material = ShaderMaterial.new()
	outline_material.shader = preload("res://Shaders/outline.gdshader")
	model = Node3D.new()
	add_child(model)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.72, 0.58)
	add_box(Vector3(0.14, 0.04, 0.16), Vector3.ZERO, 0.0, material)
	for i in 4:
		var length := 0.11 if i in [1, 2] else 0.09
		add_box(Vector3(0.03, 0.03, length), Vector3(-0.05 + i * 0.033, 0.0, -0.08 - length / 2.0), 0.0, material)
	add_box(Vector3(0.03, 0.03, 0.09), Vector3(0.1, 0.0, -0.04), -0.7, material)
	if is_multiplayer_authority():
		build_hud()


func add_box(size: Vector3, pos: Vector3, yaw: float, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.rotation.y = yaw
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(mesh_instance)


func _process(delta: float) -> void:
	if player == null or model == null:
		return
	if player.is_dead:
		pulling = false
		charging = false
	if charging:
		charge = minf(charge + delta, push_max_charge)
	if hud_layer:
		hud_layer.visible = equipped and not player.is_dead
		var ratio := charge_ratio()
		hud_fill.size.x = 234.0 * ratio
		hud_fill.color = Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.3, 0.2), ratio)
	push_t = minf(push_t + delta / push_anim_time, 1.0)
	var offset := Vector3.ZERO
	var tilt := Vector3.ZERO
	if pulling:
		offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount
		tilt = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.05
	# Wind the hand back while charging, then lunge forward on release.
	if charging:
		offset.z += 0.15 * charge / push_max_charge
	offset.z -= sin(push_t * PI) * push_lunge
	model.position = offset
	model.rotation = tilt


func primary_action() -> void:
	set_charging.rpc(true)


func primary_released() -> void:
	if not charging:
		return
	var ratio := charge_ratio()
	set_charging.rpc(false)
	play_push.rpc()
	request_push.rpc_id(1, ratio)


func charge_ratio() -> float:
	return clampf(charge / push_max_charge, 0.0, 1.0)


# Every peer charges locally from the start/stop signal, so the server can tremble the held object too.
@rpc("any_peer", "call_local", "reliable")
func set_charging(value: bool) -> void:
	if not is_from_owner():
		return
	charging = value
	charge = 0.0


func build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.visible = false
	add_child(hud_layer)
	var label := Label.new()
	label.text = "FORCE PUSH"
	label.position = Vector2(20, -128)
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.add_theme_font_size_override("font_size", 12)
	hud_layer.add_child(label)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.6)
	back.size = Vector2(240, 14)
	back.position = Vector2(20, -108)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	back.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_layer.add_child(back)
	hud_fill = ColorRect.new()
	hud_fill.position = Vector2(3, 3)
	hud_fill.size = Vector2(0, 8)
	back.add_child(hud_fill)


func secondary_action() -> void:
	if selected == null or not is_instance_valid(selected):
		return
	set_pulling.rpc(true)
	request_grab.rpc_id(1, selected.get_path())


func secondary_released() -> void:
	if not pulling:
		return
	set_pulling.rpc(false)
	request_release.rpc_id(1)


func unequip() -> void:
	super()
	set_selected(null)


# Local only: the body under the crosshair is selected and outlined until it is pulled or lost.
func update_selection() -> void:
	if selected != null and (not is_instance_valid(selected) or selected.get("available") == false):
		set_selected(null)
		if pulling:
			set_pulling.rpc(false)
	if pulling:
		return
	var origin: Vector3 = player.head.global_position
	var forward: Vector3 = -player.head.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * grab_range, 0xFFFFFFFF, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	set_selected(hit.collider if not hit.is_empty() and hit.collider is RigidBody3D else null)


func set_selected(body: RigidBody3D) -> void:
	if body == selected:
		return
	set_outline(selected, false)
	selected = body
	set_outline(selected, true)


func set_outline(body: RigidBody3D, enabled: bool) -> void:
	if not is_instance_valid(body):
		return
	for child in body.get_children():
		if child is MeshInstance3D:
			child.material_overlay = outline_material if enabled else null


func is_from_owner() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == 0 or sender == player.get_multiplayer_authority()


@rpc("any_peer", "call_local", "reliable")
func set_pulling(value: bool) -> void:
	if is_from_owner():
		pulling = value


@rpc("any_peer", "call_local", "reliable")
func play_push() -> void:
	if is_from_owner():
		push_t = 0.0


# Runs on the server only, because rigid bodies are simulated there.
@rpc("any_peer", "call_local", "reliable")
func request_grab(body_path: NodePath) -> void:
	if not multiplayer.is_server() or player.is_dead or not is_from_owner():
		return
	release_hold()
	var body := get_node_or_null(body_path) as RigidBody3D
	if body == null or body.global_position.distance_to(player.head.global_position) > grab_range + grab_tolerance:
		return
	held_body = body
	held_body.set_meta("held_by", player)
	# Anchored bridge blocks are frozen, so they must be released before they can be pulled.
	if "anchored" in held_body:
		held_body.anchored = false
		held_body.freeze = false
	held_gravity = held_body.gravity_scale
	held_body.gravity_scale = 0.0


@rpc("any_peer", "call_local", "reliable")
func request_release() -> void:
	if multiplayer.is_server() and is_from_owner():
		release_hold()


func release_hold() -> void:
	if is_instance_valid(held_body):
		held_body.gravity_scale = held_gravity
		held_body.remove_meta("held_by")
	held_body = null


func _physics_process(delta: float) -> void:
	if equipped and is_multiplayer_authority() and not player.is_dead:
		update_selection()
	elif selected != null:
		set_selected(null)
	if not multiplayer.is_server() or held_body == null:
		return
	if not is_instance_valid(held_body) or player.is_dead or held_body.get("available") == false:
		release_hold()
		return
	var half := 0.0
	var body_size: Variant = held_body.get("size")
	if body_size is Vector3:
		half = body_size.length() / 2.0
	var forward: Vector3 = -player.head.global_basis.z
	var right: Vector3 = player.head.global_basis.x
	var target: Vector3 = player.head.global_position + forward * (hover_distance + half) + right * hover_side_offset
	var velocity := ((target - held_body.global_position) * pull_stiffness).limit_length(pull_max_speed)
	# Pickups are collected the moment the pull brings them to the player.
	if held_body.has_method("collect") and held_body.global_position.distance_to(target) < collect_distance:
		var pickup := held_body
		if pickup.collect(player):
			release_hold()
			return
	held_body.linear_velocity = velocity
	held_body.angular_velocity = held_body.angular_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
	# The held object trembles harder the more force is charged.
	var tremble := charge_ratio() if charging else 0.0
	if tremble > 0.0:
		held_body.linear_velocity += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tremble_speed * tremble
		held_body.angular_velocity += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * tremble_spin * tremble
	held_body.sleeping = false


# Pushes everything in a box in front of the head, including the held object.
@rpc("any_peer", "call_local", "reliable")
func request_push(ratio: float) -> void:
	if not multiplayer.is_server() or player.is_dead or not is_from_owner():
		return
	var now := Time.get_ticks_msec()
	if now - last_push_msec < push_cooldown * 1000.0:
		return
	last_push_msec = now
	release_hold()
	var speed := lerpf(push_min_speed, push_max_speed, clampf(ratio, 0.0, 1.0))
	var aim: Basis = player.head.global_basis.orthonormalized()
	var forward := -aim.z
	var box := BoxShape3D.new()
	box.size = Vector3(push_width, push_width, push_range)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(aim, player.head.global_position + forward * push_range / 2.0)
	query.exclude = [player.get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body: Node3D = hit.collider
		if body is RigidBody3D:
			body.apply_central_impulse(forward * speed * body.mass)
		elif body.has_method("apply_knockback_networked"):
			body.apply_knockback_networked(forward * speed)
