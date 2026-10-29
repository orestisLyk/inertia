extends Node3D

const BLOCK_SCENE: PackedScene = preload("res://Scenes/rigid_block.tscn")
const BRIDGE_BLOCK_SCENE: PackedScene = preload("res://Scenes/bridge_block.tscn")
const STATIC_BLOCK_SCENE: PackedScene = preload("res://Scenes/block.tscn")
const BAZOOKA_PICKUP_SCENE: PackedScene = preload("res://Scenes/bazooka_pickup.tscn")
const TOP := -2.04
const ISLAND_OFFSET := 14.0
const ISLAND_SIZE := 14.0
const ISLAND_THICKNESS := 2.0
const PLANKS := 6
const PLANK := Vector3(2.3, 0.5, 4.0)

var block_count := 0


# Every peer builds the same layout with the same node names, so the synced blocks match up.
func _ready() -> void:
	var corners: Array[Vector2] = []
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			corners.append(Vector2(x, z) * ISLAND_OFFSET)
	for corner in corners:
		island(corner)
		add_block(corner, TOP, Vector3(3, 3, 3))
		add_block(corner + Vector2(3.5, -3.5), TOP, Vector3(1.5, 1.5, 1.5))
		add_block(corner + Vector2(-3.5, 3.5), TOP, Vector3(1.5, 1.5, 1.5))
	var half := ISLAND_OFFSET
	bridge(Vector2(0, -half), 0.0)
	bridge(Vector2(0, half), 0.0)
	bridge(Vector2(-half, 0), PI / 2.0)
	bridge(Vector2(half, 0), PI / 2.0)
	add_bazooka(Vector2(ISLAND_OFFSET - 4.5, 	ISLAND_OFFSET), "BazookaPickup")
		add_bazooka(Vector2(-ISLAND_OFFSET + 4.5, -ISLAND_OFFSET), "BazookaPickup2")


	# A single-shot bazooka hovering on an island.
	func add_bazooka(xz: Vector2, pickup_name: String) -> void:
		var pickup := BAZOOKA_PICKUP_SCENE.instantiate() as Node3D
		pickup.name = pickup_name
		pickup.set("ammo", 1)
		pickup.position = Vector3(xz.x, TOP + 1.0, xz.y)
	add_child(pickup)


func get_spawn_position(height: float) -> Vector3:
	var corner := Vector2(signf(randf() - 0.5), signf(randf() - 0.5)) * ISLAND_OFFSET
	var spot := corner + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	return Vector3(spot.x, height, spot.y)


func island(center: Vector2) -> void:
	var body := STATIC_BLOCK_SCENE.instantiate() as Node3D
	body.name = "Island%d" % get_child_count()
	body.scale = Vector3(ISLAND_SIZE, ISLAND_THICKNESS, ISLAND_SIZE)
	body.position = Vector3(center.x, TOP - ISLAND_THICKNESS / 2.0, center.y)
	add_child(body)


func add_block(xz: Vector2, bottom: float, size: Vector3, yaw := 0.0, scene: PackedScene = BLOCK_SCENE) -> Node:
	var block := scene.instantiate()
	block.name = "Block%d" % block_count
	block_count += 1
	block.set("size", size)
	block.position = Vector3(xz.x, bottom + size.y / 2.0 + 0.01, xz.y)
	block.rotation.y = yaw
	add_child(block)
	return block


# Planks spanning the gap between two islands; yaw is 0 for bridges along X, PI/2 along Z.
func bridge(center: Vector2, yaw: float) -> void:
	var along := Vector2.from_angle(-yaw)
	var spacing := (ISLAND_OFFSET * 2.0 - ISLAND_SIZE) / PLANKS
	for i in PLANKS:
		var offset := (i - (PLANKS - 1) / 2.0) * spacing
		var size := Vector3(spacing - 0.05, PLANK.y, PLANK.z)
		add_block(center + along * offset, TOP - PLANK.y, size, yaw, BRIDGE_BLOCK_SCENE)
