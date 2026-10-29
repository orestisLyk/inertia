extends Node3D

const EDGE_DETECTION_SHADER: Shader = preload("res://Shaders/edge_detection.gdshader")
const EXPLOSION_SCENE: PackedScene = preload("res://Scenes/explosion.tscn")

@export var spawn_radius := 4.0
@export var spawn_height := 3.0
@export var round_restart_delay := 4.0
@export var map_center := Vector3.ZERO
@export var kill_radius := 15.0

@onready var players: Node3D = $Players

var round_active := true
var player_names := {}
var round_label: Label
var menu: Control
var address_field: LineEdit
var status_label: Label
var lobby_label: Label
var ping_label: Label
var ping_timer := 0.0
var wins := {}
var scoreboard: PanelContainer
var scoreboard_label: Label


func _ready() -> void:
	_add_edge_detection()
	build_menu()
	Network.steam_lobby_hosted.connect(_on_steam_lobby_hosted)
	Network.steam_failed.connect(_on_steam_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _add_edge_detection() -> void:
	# A full-screen quad: spatial shaders can read depth and normals, canvas_item shaders can't.
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var edge_material := ShaderMaterial.new()
	edge_material.shader = EDGE_DETECTION_SHADER
	quad.material = edge_material

	var edge_overlay := MeshInstance3D.new()
	edge_overlay.name = "EdgeDetection"
	edge_overlay.mesh = quad
	edge_overlay.extra_cull_margin = 16384.0
	edge_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(edge_overlay)


func _process(delta: float) -> void:
	update_ping(delta)
	update_scoreboard()


# Measured with a reliable RPC round trip, so it works for both ENet and Steam and
# includes any stalls from packet loss.
func update_ping(delta: float) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		ping_label.text = ""
		return
	if multiplayer.is_server():
		ping_label.text = "Host"
		return
	ping_timer -= delta
	if ping_timer <= 0.0:
		ping_timer = 1.0
		ping_request.rpc_id(1, Time.get_ticks_msec())


@rpc("any_peer", "call_remote", "reliable")
func ping_request(sent_msec: int) -> void:
	if multiplayer.is_server():
		ping_reply.rpc_id(multiplayer.get_remote_sender_id(), sent_msec)


@rpc("authority", "call_remote", "reliable")
func ping_reply(sent_msec: int) -> void:
	ping_label.text = "Ping: %d ms" % (Time.get_ticks_msec() - sent_msec)


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	despawn_out_of_bounds_items()
	if round_active:
		check_out_of_bounds()


# Server only. Rockets and rigid blocks past kill_radius are removed on every peer.
func despawn_out_of_bounds_items() -> void:
	for rocket in $Rockets.get_children():
		if not rocket.is_queued_for_deletion() and is_out_of_bounds(rocket.global_position):
			rocket.queue_free()
	for block in get_tree().get_nodes_in_group("rigid_blocks"):
		if not block.is_queued_for_deletion() and is_out_of_bounds(block.global_position):
			block.despawn.rpc()


# Server only. Anyone farther than kill_radius from map_center dies.
func check_out_of_bounds() -> void:
	for player in players.get_children():
		if not player.is_dead and not player.awaiting_respawn and is_out_of_bounds(player.global_position):
			player.die()


func is_out_of_bounds(point: Vector3) -> bool:
	return point.distance_to(map_center) > kill_radius


func build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	round_label = Label.new()
	round_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	round_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	round_label.add_theme_font_size_override("font_size", 32)
	layer.add_child(round_label)
	menu = VBoxContainer.new()
	menu.position = Vector2(16, 16)
	layer.add_child(menu)

	address_field = LineEdit.new()
	address_field.text = "127.0.0.1"
	address_field.placeholder_text = "IP address or Steam lobby ID"
	address_field.custom_minimum_size.x = 260
	menu.add_child(address_field)

	add_menu_button("Host (LAN/IP)", host_game)
	add_menu_button("Join (LAN/IP)", join_game)
	if Network.is_steam_available():
		add_menu_button("Host (Steam)", host_steam_game)
		add_menu_button("Join (Steam lobby ID)", join_steam_game)

	status_label = Label.new()
	menu.add_child(status_label)

	lobby_label = Label.new()
	lobby_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lobby_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lobby_label.position = Vector2(16, -16)
	layer.add_child(lobby_label)

	ping_label = Label.new()
	ping_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ping_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ping_label.position = Vector2(-16, 16)
	layer.add_child(ping_label)

	scoreboard = PanelContainer.new()
	scoreboard.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scoreboard.grow_vertical = Control.GROW_DIRECTION_BOTH
	scoreboard.visible = false
	scoreboard_label = Label.new()
	scoreboard.add_child(scoreboard_label)
	layer.add_child(scoreboard)


# Hold Tab to see round wins.
func update_scoreboard() -> void:
	scoreboard.visible = Input.is_key_pressed(KEY_TAB) and players.get_child_count() > 0
	if not scoreboard.visible:
		return
	var ids: Array = []
	for player in players.get_children():
		ids.append(player.name.to_int())
	ids.sort_custom(func(a: int, b: int) -> bool: return wins.get(a, 0) > wins.get(b, 0))
	var text := "SCOREBOARD\n"
	for id: int in ids:
		text += "\n%s   %d" % [get_player_name(id), wins.get(id, 0)]
	scoreboard_label.text = text


func add_menu_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	menu.add_child(button)


func host_steam_game() -> void:
	status_label.text = "Creating Steam lobby..."
	Network.host_steam()


func join_steam_game() -> void:
	status_label.text = "Joining Steam lobby..."
	Network.join_steam(address_field.text.to_int())


func _on_steam_lobby_hosted(lobby_id: int) -> void:
	menu.hide()
	lobby_label.text = "Steam lobby ID: %d" % lobby_id
	add_player(1)
	submit_name(get_local_name())


func _on_steam_failed(message: String) -> void:
	status_label.text = message


func host_game() -> void:
	var error := Network.host()
	if error != OK:
		status_label.text = "Host failed: %s" % error_string(error)
		return
	menu.hide()
	add_player(1)


func join_game() -> void:
	var error := Network.join(address_field.text)
	if error != OK:
		status_label.text = "Join failed: %s" % error_string(error)
		return
	status_label.text = "Connecting..."


func add_player(id: int) -> void:
	var player: Node3D = preload("res://Scenes/player.tscn").instantiate()
	player.name = str(id)
	player.position = random_spawn_position()
	player.died.connect(_on_player_died)
	players.add_child(player)


func random_spawn_position() -> Vector3:
	# Levels without a floor under the centre can provide their own spawn points.
	var level := get_node_or_null("Level")
	if level and level.has_method("get_spawn_position"):
		return level.get_spawn_position(spawn_height)
	return Vector3(randf_range(-spawn_radius, spawn_radius), spawn_height, randf_range(-spawn_radius, spawn_radius))


# Server only. Called when any player dies (rocket, traps, ...).
func _on_player_died(_player: Node3D) -> void:
	check_round_end()


# Server only. The round ends when one player is left alive (or none, if playing solo).
func check_round_end(ignore: Node = null) -> void:
	if not round_active:
		return
	var alive: Array[Node] = []
	var total := 0
	for player in players.get_children():
		if player == ignore or player.is_queued_for_deletion():
			continue
		total += 1
		if not player.is_dead:
			alive.append(player)
	var remaining_needed := 1 if total > 1 else 0
	if alive.size() > remaining_needed:
		return
	round_active = false
	end_round(alive[0].name.to_int() if alive.size() == 1 else 0)


# Override or edit this to change what happens when a round ends. winner_id is 0 if nobody survived.
func end_round(winner_id: int) -> void:
	if winner_id == 0:
		show_round_message.rpc("Round over!")
	else:
		wins[winner_id] = wins.get(winner_id, 0) + 1
		sync_wins.rpc(wins)
		show_round_message.rpc("%s wins!" % get_player_name(winner_id))
	await get_tree().create_timer(round_restart_delay).timeout
	start_round()


func start_round() -> void:
	for player in players.get_children():
		# Ignore the out-of-bounds check until the owner has applied the respawn.
		player.awaiting_respawn = true
		release_respawn_guard(player, 5.0)
		player.respawn.rpc(random_spawn_position())
	show_round_message.rpc("")
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.reset()
	round_active = true


# Fallback in case a client never confirms its respawn.
func release_respawn_guard(player: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(player):
		player.awaiting_respawn = false


@rpc("authority", "call_local", "reliable")
func spawn_explosion(point: Vector3) -> void:
	var explosion: Node3D = EXPLOSION_SCENE.instantiate()
	add_child(explosion)
	explosion.global_position = point


@rpc("authority", "call_local", "reliable")
func show_round_message(text: String) -> void:
	round_label.text = text


func get_player_name(id: int) -> String:
	return player_names.get(id, "Player %d" % id)


func get_local_name() -> String:
	if Network.steam_initialized:
		return str(Network.steam.getPersonaName())
	return ""


@rpc("any_peer", "call_local", "reliable")
func submit_name(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	player_name = player_name.strip_edges().left(32)
	if player_name.is_empty():
		player_names.erase(id)
	else:
		player_names[id] = player_name
	sync_names.rpc(player_names)


@rpc("authority", "call_local", "reliable")
func sync_wins(new_wins: Dictionary) -> void:
	wins = new_wins


@rpc("authority", "call_local", "reliable")
func sync_names(names: Dictionary) -> void:
	player_names = names


func remove_player(id: int) -> void:
	player_names.erase(id)
	wins.erase(id)
	sync_names.rpc(player_names)
	sync_wins.rpc(wins)
	var player := players.get_node_or_null(str(id))
	if player:
		player.queue_free()
		check_round_end(player)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		add_player(id)
		sync_wins.rpc_id(id, wins)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		remove_player(id)


func _on_connected_to_server() -> void:
	menu.hide()
	submit_name.rpc_id(1, get_local_name())


func _on_connection_failed() -> void:
	Network.leave()
	status_label.text = "Connection failed"


func _on_server_disconnected() -> void:
	Network.leave()
	get_tree().reload_current_scene()
