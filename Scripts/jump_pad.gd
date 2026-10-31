extends Area3D

@export var launch_velocity := 18.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_multiplayer_authority():
		body.velocity.y = launch_velocity
		body.is_stomping = false
