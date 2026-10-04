extends Node

# A small WebSocket transport shared by the menu and the active world.
signal welcome_received(message: Dictionary)
signal message_received(message: Dictionary)
signal connection_failed(reason: String)
signal disconnected

const UPDATE_INTERVAL := 0.1
const CONNECT_TIMEOUT := 10.0

var socket: WebSocketPeer
var selected_dino := "triceratops"
var player_name := "Player"
var player_color := "#6ea8fe"
var player: CharacterBody3D
var connected := false
var elapsed := 0.0
var connect_time := 0.0


func connect_to_server(url: String, dino_id: String, allow_self_signed := false, display_name := "Player", color := "#6ea8fe") -> Error:
	disconnect_from_server()
	selected_dino = dino_id
	player_name = display_name
	player_color = color
	socket = WebSocketPeer.new()
	var tls_options: TLSOptions = TLSOptions.client_unsafe() if allow_self_signed and url.begins_with("wss://") else null
	var result := socket.connect_to_url(url, tls_options)
	if result != OK:
		socket = null
		return result
	connect_time = 0.0
	set_process(true)
	return OK


func disconnect_from_server() -> void:
	if socket:
		socket.close()
	socket = null
	connected = false
	player = null
	elapsed = 0.0
	set_process(false)


func send_action(action: String) -> void:
	if connected and socket:
		socket.send_text(JSON.stringify({"type": action}))


func _process(delta: float) -> void:
	if socket == null:
		return
	socket.poll()
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not connected:
				connected = true
				socket.send_text(JSON.stringify({
					"type": "hello", "dino": selected_dino,
					"name": player_name, "color": player_color
				}))
			while socket.get_available_packet_count() > 0:
				var parsed = JSON.parse_string(socket.get_packet().get_string_from_utf8())
				if not parsed is Dictionary:
					continue
				var message := parsed as Dictionary
				if message.get("type") == "welcome":
					welcome_received.emit(message)
				elif message.get("type") == "rejected":
					connection_failed.emit(str(message.get("reason", "rejected")))
					disconnect_from_server()
					return
				else:
					message_received.emit(message)
					if socket == null:
						return
			if is_instance_valid(player) and connected:
				elapsed += delta
				if elapsed >= UPDATE_INTERVAL:
					elapsed = 0.0
					var motion := "run" if player.velocity.length() > 5.0 else ("walk" if player.velocity.length() > 0.3 else "idle")
					if bool(player.get("eating_active")):
						motion = "eat"
					elif float(player.get("attack_time")) > 0.0:
						motion = "attack"
					elif float(player.get("scream_time")) > 0.0:
						motion = "scream"
					socket.send_text(JSON.stringify({
						"type": "state", "x": player.global_position.x,
						"y": player.global_position.y, "z": player.global_position.z,
						"yaw": player.rotation.y, "animation": motion
					}))
		WebSocketPeer.STATE_CONNECTING:
			connect_time += delta
			if connect_time >= CONNECT_TIMEOUT:
				connection_failed.emit("timeout")
				disconnect_from_server()
		WebSocketPeer.STATE_CLOSED:
			var was_connected := connected
			disconnect_from_server()
			if was_connected:
				disconnected.emit()
			else:
				connection_failed.emit("unreachable")
