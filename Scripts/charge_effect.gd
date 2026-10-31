extends RefCounted

# Visual-only "charging" effect for an item: its meshes jitter with noise (position and rotation)
# and get a distortion shader. Everything scales with the charge ratio (0..1).
# Collision shapes and the physics body are never touched.

const SHADER: Shader = preload("res://Shaders/charge_distort.gdshader")

var max_offset := 0.12
var max_angle := 0.35
var min_speed := 1.5
var max_speed := 12.0
var max_distortion := 0.12

var target: Node3D
var phase := 0.0
var noise := FastNoiseLite.new()
var meshes: Array[MeshInstance3D] = []
var bases: Array[Transform3D] = []
var materials: Array[ShaderMaterial] = []


func _init(node: Node3D) -> void:
	target = node
	noise.frequency = 1.0
	for child in node.get_children():
		if child is MeshInstance3D and not child.top_level:
			add_mesh(child)


func add_mesh(mesh_instance: MeshInstance3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var source := mesh_instance.get_active_material(0)
	if source is StandardMaterial3D:
		material.set_shader_parameter("albedo", source.albedo_color)
		if source.albedo_texture:
			material.set_shader_parameter("albedo_texture", source.albedo_texture)
			material.set_shader_parameter("use_texture", true)
	mesh_instance.material_override = material
	meshes.append(mesh_instance)
	bases.append(mesh_instance.transform)
	materials.append(material)


func is_valid() -> bool:
	return is_instance_valid(target)


func sample(channel: int) -> float:
	return noise.get_noise_2d(phase, channel * 37.0)


# Call every frame while the effect is active.
func update(delta: float, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	phase += delta * lerpf(min_speed, max_speed, ratio)
	var offset := Vector3(sample(0), sample(1), sample(2)) * max_offset * ratio
	var spin := Vector3(sample(3), sample(4), sample(5)) * max_angle * ratio
	var jitter := Transform3D(Basis.from_euler(spin), offset)
	for i in meshes.size():
		if not is_instance_valid(meshes[i]):
			continue
		meshes[i].transform = jitter * bases[i]
		var material := materials[i]
		material.set_shader_parameter("fx_time", phase)
		material.set_shader_parameter("distortion", max_distortion * ratio)


# Puts the meshes back exactly as they were.
func clear() -> void:
	for i in meshes.size():
		if not is_instance_valid(meshes[i]):
			continue
		meshes[i].transform = bases[i]
		if meshes[i].material_override == materials[i]:
			meshes[i].material_override = null
	meshes.clear()
	bases.clear()
	materials.clear()
