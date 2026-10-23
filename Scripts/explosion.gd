extends Node3D

@onready var fire: GPUParticles3D = $Fire
@onready var sparks: GPUParticles3D = $Sparks
@onready var sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	fire.restart()
	sparks.restart()
	sound.play()
	var duration := maxf(maxf(fire.lifetime, sparks.lifetime), sound.stream.get_length())
	await get_tree().create_timer(duration + 0.5).timeout
	queue_free()
