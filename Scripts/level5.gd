extends Node3D

const BLOCK_SCENE: PackedScene = preload("res://Scenes/rigid_block.tscn")
const BRIDGE_BLOCK_SCENE: PackedScene = preload("res://Scenes/bridge_block.tscn")
const STATIC_BLOCK_SCENE: PackedScene = preload("res://Scenes/block.tscn")
const BAZOOKA_PICKUP_SCENE: PackedScene = preload("res://Scenes/bazooka_pickup.tscn")
const JUMP_PAD_SCENE: PackedScene = preload("res://Scenes/jump_pad.tscn")
const GROUND_TOP := -2.04
const GROUND_SIZE := 36.0
const THICKNESS := 1.0
const TIER1 := 6.0
const TIER2 := 16.0
const TIER3 := 26.0
const PLANKS := 6
const PLANK := Vector3(2.3, 0.5, 4.0)

var block_count := 0
var platform_count := 0
var pad_count := 0
var bazooka_count := 0


# Every peer builds the same layout with the same node names, so the synced nodes match up.
func _ready() -> void:
	var ground := STATIC_BLOCK_SCENE.instantiate() as Node3D
	ground.name = "Ground"
	ground.scale = Vector3(GROUND_SIZE, 2.0, GROUND_SIZE)
	ground.position = Vector3(0, GROUND_TOP - 1.0, 0)
	add_child(ground)

	# Tier 1: four platforms over the ground, each with a launch pad beside it.
	for x in [-12.0, 12.0]:
		for z in [-12.0, 12.0]:
			platform(Vector2(x, z), TIER1, 8.0)
			pad(Vector2(x, z * 5.0 / 12.0), GROUND_TOP)
			# Pad on tier 1 launching to tier 2.
			pad(Vector2(x, z * 9.0 / 12.0), TIER1)
	# Tier 2: two side platforms, each with pads launching up to the summit.
	for x in [-12.0, 12.0]:
		platform(Vector2(x, 0), TIER2, 8.0)
		pad(Vector2(x * 9.0 / 12.0, 0), TIER2)
	# Tier 3: the summit.
	platform(Vector2.ZERO, TIER3, 10.0)

	# Bridges between the platforms of each tier.
	bridge(Vector2(0, -12), TIER1)
	bridge(Vector2(0, 12), TIER1)
	bridge(Vector2(0, 0), TIER2)

	add_bazooka(Vector2(0, 0), TIER3)
	add_bazooka(Vector2(12, 0), TIER2)
	add_bazooka(Vector2(-12, 0), TIER2)
	add_bazooka(Vector2(0, 15), GROUND_TOP)
	add_bazooka(Vector2(0, -15), GROUND_TOP)
	build_structures()


func build_structures() -> void:
	# Ground: a pyramid in the middle and low walls to hide behind.
	pyramid(Vector2(0, 0), GROUND_TOP)
	add_block(Vector2(-7, -7), GROUND_TOP, Vector3(5, 2.5, 1))
	add_block(Vector2(7, 7), GROUND_TOP, Vector3(5, 2.5, 1))
	add_block(Vector2(7, -7), GROUND_TOP, Vector3(1, 2.5, 5))
	add_block(Vector2(-7, 7), GROUND_TOP, Vector3(1, 2.5, 5))
	# Tier 1: a tower in the outer corner of each platform.
	for x in [-15.0, 15.0]:
		for z in [-15.0, 15.0]:
			add_block(Vector2(x, z), TIER1, Vector3(1.5, 1.5, 1.5))
			add_block(Vector2(x, z), TIER1 + 1.5, Vector3(1.5, 1.5, 1.5))
			add_block(Vector2(x, z), TIER1 + 3.0, Vector3(1.5, 1.5, 1.5))
	# Tier 2: an archway of two pillars and a lintel on each platform.
	for x in [-14.0, 14.0]:
		add_block(Vector2(x, -2.5), TIER2, Vector3(1.2, 3, 1.2))
		add_block(Vector2(x, 2.5), TIER2, Vector3(1.2, 3, 1.2))
		add_block(Vector2(x, 0), TIER2 + 3.0, Vector3(1.2, 1, 6.2))
	# Summit: a few crates around the edge.
	add_block(Vector2(3.5, 3.5), TIER3, Vector3(1.5, 1.5, 1.5))
	add_block(Vector2(-3.5, -3.5), TIER3, Vector3(1.5, 1.5, 1.5))
	add_block(Vector2(-3.5, 3.5), TIER3, Vector3(2, 1, 2))
	add_block(Vector2(-3.5, 3.5), TIER3 + 1.0, Vector3(1, 1, 1))


func pyramid(center: Vector2, bottom: float) -> void:
	for layer in 3:
		var side := 2.0 * (3 - layer)
		add_block(center, bottom + layer * 1.5, Vector3(side, 1.5, side))


func add_block(xz: Vector2, bottom: float, size: Vector3) -> void:
	var block := BLOCK_SCENE.instantiate()
	block.name = "Block%d" % block_count
	block_count += 1
	block.set("size", size)
	block.position = Vector3(xz.x, bottom + size.y / 2.0 + 0.01, xz.y)
	add_child(block)


func get_spawn_position(height: float) -> Vector3:
	var x := randf_range(14.0, 17.0) * signf(randf() - 0.5)
	var z := randf_range(-16.0, 16.0)
	if randf() < 0.5:
		return Vector3(x, height, z)
	return Vector3(z, height, x)


func platform(center: Vector2, top: float, size: float) -> void:
	var body := STATIC_BLOCK_SCENE.instantiate() as Node3D
	body.name = "Platform%d" % platform_count
	platform_count += 1
	body.scale = Vector3(size, THICKNESS, size)
	body.position = Vector3(center.x, top - THICKNESS / 2.0, center.y)
	add_child(body)


func pad(xz: Vector2, top: float) -> void:
	var jump_pad := JUMP_PAD_SCENE.instantiate() as Node3D
	jump_pad.name = "JumpPad%d" % pad_count
	pad_count += 1
	jump_pad.position = Vector3(xz.x, top, xz.y)
	add_child(jump_pad)


# A single-shot bazooka hovering above a surface.
func add_bazooka(xz: Vector2, top: float) -> void:
	var pickup := BAZOOKA_PICKUP_SCENE.instantiate() as Node3D
	pickup.name = "BazookaPickup%d" % bazooka_count
	bazooka_count += 1
	pickup.set("ammo", 1)
	pickup.position = Vector3(xz.x, top + 1.0, xz.y)
	add_child(pickup)


# Planks along X spanning the 16 unit gap between two 8 unit platforms.
func bridge(center: Vector2, top: float) -> void:
	var spacing := 16.0 / PLANKS
	for i in PLANKS:
		var offset := (i - (PLANKS - 1) / 2.0) * spacing
		var size := Vector3(spacing - 0.05, PLANK.y, PLANK.z)
		var block := BRIDGE_BLOCK_SCENE.instantiate()
		block.name = "Block%d" % block_count
		block_count += 1
		block.set("size", size)
		block.position = Vector3(center.x + offset, top - size.y / 2.0 + 0.01, center.y)
		add_child(block)
