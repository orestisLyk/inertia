extends Node3D

# Shows the force-push charge effect at fixed phases side by side, plus one live item you can control.
# Left to right: 0%, 25%, 50%, 75%, 100%. The last item follows the slider (or loops while "auto" is on).

const ChargeEffect := preload("res://Scripts/charge_effect.gd")
const PHASES := [0.0, 0.25, 0.5, 0.75, 1.0]
const SPACING := 2.5

var effects: Array = []
var ratios: Array[float] = []
var live_index := -1
var auto_cycle := true
var live_ratio := 0.0
var slider: HSlider
var ratio_label: Label


func _ready() -> void:
	for i in PHASES.size():
		add_item(i, PHASES[i], "%d%%" % int(PHASES[i] * 100.0))
	live_index = PHASES.size()
	add_item(live_index, 0.0, "LIVE")
	add_environment()
	add_ui()


func add_item(index: int, ratio: float, title: String) -> void:
	var holder := Node3D.new()
	holder.position = Vector3((index - (PHASES.size()) / 2.0) * SPACING, 0.0, 0.0)
	add_child(holder)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.25, 0.15) if index % 2 == 0 else Color(0.2, 0.5, 0.9)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	box.subdivide_width = 6
	box.subdivide_height = 6
	box.subdivide_depth = 6
	box.material = material
	body.mesh = box
	holder.add_child(body)
	var label := Label3D.new()
	label.text = title
	label.position = Vector3(0.0, -1.3, 0.0)
	label.pixel_size = 0.01
	label.font_size = 48
	holder.add_child(label)
	effects.append(ChargeEffect.new(holder))
	ratios.append(ratio)


func add_environment() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.5, 9.0)
	add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.08, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(env)


func add_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(20.0, 20.0)
	layer.add_child(box)
	ratio_label = Label.new()
	box.add_child(ratio_label)
	slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(300.0, 20.0)
	slider.value_changed.connect(func(value: float) -> void: live_ratio = value)
	box.add_child(slider)
	var auto := CheckButton.new()
	auto.text = "Auto cycle"
	auto.button_pressed = true
	auto.toggled.connect(func(on: bool) -> void: auto_cycle = on)
	box.add_child(auto)


func _process(delta: float) -> void:
	if auto_cycle:
		live_ratio = fmod(live_ratio + delta / 3.0, 1.0)
		slider.set_value_no_signal(live_ratio)
	ratios[live_index] = live_ratio
	ratio_label.text = "Live charge: %d%%" % int(live_ratio * 100.0)
	for i in effects.size():
		effects[i].update(delta, ratios[i])
