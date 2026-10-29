extends "res://Scripts/weapon.gd"

@export var rocket_scene: PackedScene = preload("res://Scenes/rocket.tscn")
@export var fire_cooldown := 0.3
@export var max_fire_origin_error := 5.0

@onready var muzzle: Node3D = $Muzzle

# Set when picked up; the bazooka is discarded once this runs out.
var ammo := 0
var last_fire_msec := 0


func primary_action() -> void:
	if ammo <= 0:
		return
	request_fire.rpc_id(1, muzzle.global_position, player.head.global_basis)


# Runs on the server only; clients ask, the server spawns the rocket.
@rpc("any_peer", "call_local", "reliable")
func request_fire(origin: Vector3, aim: Basis) -> void:
	if not multiplayer.is_server() or player.is_dead or ammo <= 0:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != player.get_multiplayer_authority():
		return
	var now := Time.get_ticks_msec()
	if now - last_fire_msec < fire_cooldown * 1000.0:
		return
	last_fire_msec = now
	if origin.distance_to(muzzle.global_position) > max_fire_origin_error:
		origin = muzzle.global_position
	spawn_rocket(origin, aim.orthonormalized())
	ammo -= 1
	if ammo <= 0:
		player.discard_bazooka.rpc()


func spawn_rocket(origin: Vector3, aim: Basis) -> void:
	var rocket := rocket_scene.instantiate() as Node3D
	rocket.transform = Transform3D(aim, origin)
	rocket.launch(player)
	player.get_node("../../Rockets").add_child(rocket, true)
