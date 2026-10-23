extends Node

signal steam_lobby_hosted(lobby_id: int)
signal steam_failed(message: String)

const PORT := 7777
const MAX_CLIENTS := 8
const STEAM_APP_ID := 480 # Valve's test app; replace with your own app ID when you have one.
const STEAM_RESULT_OK := 1
const STEAM_LOBBY_ENTER_SUCCESS := 1
const STEAM_LOBBY_TYPE_FRIENDS_ONLY := 1

var steam: Variant = null
var steam_initialized := false
var lobby_id := 0


func is_steam_available() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_CLIENTS)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	return error


func init_steam() -> bool:
	if steam_initialized:
		return true
	if not is_steam_available():
		steam_failed.emit("GodotSteam plugin not installed")
		return false
	steam = Engine.get_singleton("Steam")
	var result: Dictionary = steam.steamInitEx(STEAM_APP_ID, true)
	if result.get("status", 1) != 0:
		steam_failed.emit("Steam init failed: %s" % result.get("verbal", "unknown error"))
		return false
	steam.lobby_created.connect(_on_lobby_created)
	steam.lobby_joined.connect(_on_lobby_joined)
	steam.join_requested.connect(_on_join_requested)
	steam_initialized = true
	return true


# The host is the server. Friends join through the lobby ID or a Steam invite.
func host_steam() -> void:
	if init_steam():
		steam.createLobby(STEAM_LOBBY_TYPE_FRIENDS_ONLY, MAX_CLIENTS)


func join_steam(id: int) -> void:
	if init_steam():
		steam.joinLobby(id)


func leave() -> void:
	multiplayer.multiplayer_peer = null
	if steam_initialized and lobby_id != 0:
		steam.leaveLobby(lobby_id)
	lobby_id = 0


func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != STEAM_RESULT_OK:
		steam_failed.emit("Failed to create lobby (error %d)" % result)
		return
	lobby_id = new_lobby_id
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.create_host(0)
	peer.server_relay = true
	multiplayer.multiplayer_peer = peer
	print("Steam lobby ID: %d" % lobby_id)
	DisplayServer.clipboard_set(str(lobby_id))
	steam_lobby_hosted.emit(lobby_id)


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != STEAM_LOBBY_ENTER_SUCCESS:
		steam_failed.emit("Failed to join lobby (response %d)" % response)
		return
	var owner_id: int = steam.getLobbyOwner(joined_lobby_id)
	# The host's own lobby join also fires this callback; it already has its peer.
	if owner_id == steam.getSteamID():
		return
	lobby_id = joined_lobby_id
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.create_client(owner_id, 0)
	peer.server_relay = true
	multiplayer.multiplayer_peer = peer


func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		join_steam(requested_lobby_id)
