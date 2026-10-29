extends Node3D

const BLOCK_SCENE: PackedScene = preload("res://Scenes/rigid_block.tscn")
const BRIDGE_BLOCK_SCENE: PackedScene = preload("res://Scenes/bridge_block.tscn")
const GROUND_TOP := -2.04

var block_count := 0


# Every peer builds the same layout with the same node names, so the synced blocks match up.
func _ready() -> void:
	pyramid(Vector2(-30, -30), 5, 2.0)
	pyramid(Vector2(32, -28), 4, 2.0)
	pyramid(Vector2(-34, 30), 4, 2.0)
	pyramid(Vector2(30, 34), 5, 2.0)

	tower(Vector2(15, -15), 6, 1.5)
	tower(Vector2(-15, 15), 6, 1.5)
	tower(Vector2(-20, -8), 5, 1.5)
	tower(Vector2(22, 8), 5, 1.5)
	tower(Vector2(0, -40), 6, 2.0)
	tower(Vector2(0, 40), 6, 2.0)

	wall(Vector2(-12, 22), 6, 3, Vector3(3, 1.5, 1))
	wall(Vector2(14, -24), 6, 3, Vector3(3, 1.5, 1))
	wall(Vector2(-40, 0), 6, 3, Vector3(3, 1.5, 1), PI / 2.0)
	wall(Vector2(40, 2), 6, 3, Vector3(3, 1.5, 1), PI / 2.0)

	stairs(Vector2(-45, -40), 4, Vector3(4, 0.8, 4))
	stairs(Vector2(45, 40), 4, Vector3(4, 0.8, 4))

	for i in 8:
		var angle := TAU * i / 8.0
		add_block(Vector2.from_angle(angle) * 25.0, GROUND_TOP, Vector3(1.5, 6.0, 1.5))
	for i in 6:
		var angle := TAU * (i + 0.5) / 6.0
		add_block(Vector2.from_angle(angle) * 44.0, GROUND_TOP, Vector3(4, 4, 4), angle)

	add_block(Vector2(0, 20), GROUND_TOP, Vector3(8, 1, 8))
	add_block(Vector2(0, -20), GROUND_TOP, Vector3(8, 1, 8))

	bridge(Vector2(0, 0), 10, 4, Vector3(2.2, 0.5, 4.0), 1.75)


func add_block(xz: Vector2, bottom: float, size: Vector3, yaw := 0.0, scene: PackedScene = BLOCK_SCENE) -> Node:
	var block := scene.instantiate()
	block.name = "Block%d" % block_count
	block_count += 1
	block.set("size", size)
	block.position = Vector3(xz.x, bottom + size.y / 2.0 + 0.01, xz.y)
	block.rotation.y = yaw
	add_child(block)
	return block


# Elevated deck along X made of planks that break loose when blasted, with sturdy steps at both ends.
func bridge(center: Vector2, planks: int, steps: int, plank: Vector3, step_height: float) -> void:
	var deck_bottom := GROUND_TOP + step_height * steps - plank.y
	var spacing := plank.x + 0.05
	for i in planks:
		var x := (i - (planks - 1) / 2.0) * spacing
		add_block(center + Vector2(x, 0), deck_bottom, plank, 0.0, BRIDGE_BLOCK_SCENE)
	var half_deck := planks * spacing / 2.0
	for i in steps:
		var offset := half_deck + 1.0 + (steps - 1 - i) * 2.0
		var size := Vector3(2.0, step_height * (i + 1), plank.z)
		for side in [-1.0, 1.0]:
			var step := add_block(center + Vector2(side * offset, 0), GROUND_TOP, size, 0.0, BRIDGE_BLOCK_SCENE)
			step.set("break_threshold", 40.0)

func pyramid(center: Vector2, levels: int, cube: float) -> void:
	for level in levels:
		var per_row := levels - level
		for i in per_row:
			var offset := (i - (per_row - 1) / 2.0) * cube
			add_block(center + Vector2(offset, 0), GROUND_TOP + level * (cube + 0.02), Vector3.ONE * cube)


func tower(center: Vector2, height: int, cube: float) -> void:
	for level in height:
		add_block(center, GROUND_TOP + level * (cube + 0.02), Vector3.ONE * cube)


# Rows of bricks, offset every other row like a brick wall.
func wall(center: Vector2, bricks_per_row: int, rows: int, brick: Vector3, yaw := 0.0) -> void:
	var along := Vector2.from_angle(yaw)
	for row in rows:
		for i in bricks_per_row:
			var offset := (i - (bricks_per_row - 1) / 2.0 + (row % 2) * 0.5) * (brick.x + 0.05)
			add_block(center + along * offset, GROUND_TOP + row * (brick.y + 0.02), brick, -yaw)


func stairs(start: Vector2, steps: int, step: Vector3) -> void:
	for i in steps:
		var height := step.y * (i + 1)
		add_block(start + Vector2(0, i * (step.z + 0.1)), GROUND_TOP, Vector3(step.x, height, step.z))
