extends Node3D

@onready var fire: GPUParticles3D = $Fire
@onready var sparks: GPUParticles3D = $Sparks


func _ready() -> void:
	fire.restart()
	sparks.restart()
	await get_tree().create_timer(maxf(fire.lifetime, sparks.lifetime) + 0.5).timeout
	queue_free()
