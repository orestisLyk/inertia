extends RigidBody3D

@export var size := Vector3.ONE
@export var density := 1.0

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	# Rigid bodies can't be scaled, so each block builds its own shape and mesh at its size.
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	var box_mesh := mesh_instance.mesh.duplicate() as BoxMesh
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mass = size.x * size.y * size.z * density
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC


func _physics_process(_delta: float) -> void:
	# Only the server simulates; clients just follow the synced transform.
	var should_freeze := not multiplayer.is_server()
	if freeze != should_freeze:
		freeze = should_freeze
