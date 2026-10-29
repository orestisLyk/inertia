extends Node3D

# Starry sky above and a field of mountains far below the level.
@export var terrain_size := 700.0
@export var terrain_resolution := 96
@export var base_height := -75.0
@export var mountain_height := 55.0
@export var noise_seed := 4

const SKY_SHADER: Shader = preload("res://Shaders/star_sky.gdshader")


func _ready() -> void:
	add_environment()
	add_child(build_terrain())


func add_environment() -> void:
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.55)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	moon.light_color = Color(0.75, 0.8, 1.0)
	moon.light_energy = 0.7
	add_child(moon)


func build_terrain() -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 4
	noise.frequency = 0.006
	var step := terrain_size / terrain_resolution
	var half := terrain_size / 2.0
	var heights := PackedFloat32Array()
	for iz in terrain_resolution + 1:
		for ix in terrain_resolution + 1:
			var x := ix * step - half
			var z := iz * step - half
			# Ridged noise is 0..1-ish with sharp peaks; fall off at the edge so the field ends low.
			var edge := 1.0 - clampf(maxf(absf(x), absf(z)) / half, 0.0, 1.0)
			heights.append(base_height + clampf(noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0) * mountain_height * smoothstep(0.0, 0.25, edge))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in terrain_resolution:
		for ix in terrain_resolution:
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var cx: int = ix + corner.x
				var cz: int = iz + corner.y
				var height := heights[cz * (terrain_resolution + 1) + cx]
				var t := clampf((height - base_height) / mountain_height, 0.0, 1.0)
				# Dark rock at the bottom, pale snow near the peaks.
				surface.set_color(Color(0.12, 0.13, 0.2).lerp(Color(0.8, 0.85, 0.95), smoothstep(0.55, 0.9, t)))
				surface.add_vertex(Vector3(cx * step - half, height, cz * step - half))
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var terrain := MeshInstance3D.new()
	terrain.name = "Mountains"
	terrain.mesh = surface.commit()
	terrain.material_override = material
	return terrain
