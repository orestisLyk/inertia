extends Node3D

# Base for held weapons. The player calls these on mouse clicks (local authority only).
var player: CharacterBody3D
var equipped := false


func setup(owner_player: CharacterBody3D) -> void:
	player = owner_player


func equip() -> void:
	equipped = true


func primary_action() -> void:
	pass


func secondary_action() -> void:
	pass


func primary_released() -> void:
	pass


func secondary_released() -> void:
	pass


# Called when the player switches away, so weapons can cancel held actions.
func unequip() -> void:
	equipped = false
	primary_released()
	secondary_released()
