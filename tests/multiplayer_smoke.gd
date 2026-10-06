extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world._dismiss_splash(true)
	world.multiplayer_settings.set_value("server", "host", "127.0.0.1")
	world.multiplayer_settings.set_value("server", "port", 8765)
	world.multiplayer_settings.set_value("server", "secure", true)
	world.multiplayer_settings.set_value("server", "allow_self_signed", true)
	world._show_multiplayer_page()
	assert(world.multiplayer_page.visible and world.multiplayer_session_rows != null, "Session lobby is missing")
	for frame in 300:
		await process_frame
		if world.multiplayer_client.connected:
			break
	assert(world.multiplayer_client.connected, "Lobby did not connect over self-signed TLS")
	world._show_multiplayer_setup("join", 7, "winter")
	assert(world.multiplayer_setup_page.visible and not world.multiplayer_create_theme_row.visible and world.selected_map_theme == "winter", "Join-session form is wrong")
	world._show_multiplayer_setup("create", 0, "grassland")
	assert(world.multiplayer_setup_page.visible and world.multiplayer_create_theme_row.visible, "Create-session form is missing")
	assert(world.multiplayer_dino_cards.size() == 7 and world.multiplayer_color_buttons.size() == 8, "Player selection is incomplete")
	world._select_multiplayer_theme("desert")
	world._select_dino("stegosaurus")
	world.multiplayer_name_input.text = "Helena"
	world._select_player_color("#f47ac2")
	world._connect_multiplayer()
	for frame in 900:
		await process_frame
		if world.multiplayer_active and world.multiplayer_npcs.size() > 0:
			break
	assert(world.multiplayer_active and world.selected_map_theme == "desert", "Desert session was not created")
	assert(world.multiplayer_npcs.size() > 0 and world.world_root.find_child("WildDinosaurs", false, false) != null, "Multiplayer AI wildlife is missing")
	var multiplayer_tokens: Array[Node] = world.get_tree().get_nodes_in_group("powerup_token")
	assert(multiplayer_tokens.size() == 30, "Multiplayer map is missing power-up tokens")
	var multiplayer_token_types := {}
	for token in multiplayer_tokens:
		multiplayer_token_types[token.token_type] = true
	assert(multiplayer_token_types.has("health") and multiplayer_token_types.has("speed") and multiplayer_token_types.has("strength"), "Multiplayer power-up types are incomplete")
	assert(world.multiplayer_ai_host_id == world.multiplayer_id, "Creator should simulate wildlife")
	assert(world.multiplayer_roster[world.multiplayer_id]["name"] == "Helena", "Player identity was not synchronized")
	var session_id := int(world.multiplayer_session_id)
	assert(session_id > 0, "Created session ID was not retained")
	var second := WebSocketPeer.new()
	assert(second.connect_to_url("wss://127.0.0.1:8765/", TLSOptions.client_unsafe()) == OK, "Second client could not connect")
	for frame in 300:
		second.poll()
		if second.get_ready_state() == WebSocketPeer.STATE_OPEN:
			break
		await process_frame
	assert(second.get_ready_state() == WebSocketPeer.STATE_OPEN, "Second client did not open")
	second.send_text(JSON.stringify({"type": "list"}))
	var listed_id := 0
	for frame in 300:
		second.poll()
		while second.get_available_packet_count() > 0:
			var message = JSON.parse_string(second.get_packet().get_string_from_utf8())
			if message is Dictionary and message.get("type") == "sessions":
				for session in message["sessions"]:
					if session["map"] == "desert" and int(session["id"]) == session_id:
						listed_id = int(session["id"])
		if listed_id > 0:
			break
		await process_frame
	assert(listed_id > 0, "Created session is absent from lobby list")
	second.send_text(JSON.stringify({"type": "join", "session": listed_id, "dino": "trex", "name": "Dad", "color": "#4ecdc4"}))
	var second_welcome := {}
	for frame in 400:
		second.poll()
		while second.get_available_packet_count() > 0:
			var message = JSON.parse_string(second.get_packet().get_string_from_utf8())
			if message is Dictionary and message.get("type") == "welcome":
				second_welcome = message
		if not second_welcome.is_empty() and world.remote_players.size() == 1:
			break
		await process_frame
	assert(int(second_welcome.get("session", 0)) == listed_id and second_welcome.get("map") == "desert", "Joining player received the wrong map")
	var received_ai: bool = second_welcome.get("npcs", []).size() > 0
	for frame in 300:
		if received_ai:
			break
		second.poll()
		while second.get_available_packet_count() > 0:
			var message = JSON.parse_string(second.get_packet().get_string_from_utf8())
			if message is Dictionary and message.get("type") == "npcs" and message.get("npcs", []).size() > 0:
				received_ai = true
		await process_frame
	assert(received_ai, "Joining player did not receive AI state")
	assert(world.remote_players.size() == 1 and world.remote_players.values()[0].player_name == "Dad", "Joining player did not appear")
	second.send_text(JSON.stringify({"type": "scream"}))
	for frame in 180:
		await process_frame
		var remote = world.remote_players.values()[0]
		if is_instance_valid(remote.vocal_audio) and remote.vocal_audio.playing:
			break
	var remote = world.remote_players.values()[0]
	assert(is_instance_valid(remote.vocal_audio) and remote.vocal_audio.playing, "Remote player scream was not audible")
	var death_position: Vector3 = remote.global_position
	world._on_multiplayer_message({"type": "death", "id": remote.identifier, "dino": remote.dino_id,
		"x": death_position.x, "y": death_position.y, "z": death_position.z,
		"death": 1, "respawn_delay": 5.0})
	assert(remote.dead, "Remote player death was not displayed")
	assert(world.get_tree().get_nodes_in_group("edible_meat").size() > 0, "Player death left no edible meat")
	var respawn_data: Dictionary = second_welcome["spawn"].duplicate()
	respawn_data["x"] = death_position.x + 90.0
	respawn_data["z"] = death_position.z
	respawn_data["health"] = remote.max_health
	world._on_multiplayer_message({"type": "respawn", "player": respawn_data})
	assert(not remote.dead and remote.global_position.distance_to(death_position) > 80.0, "Remote player did not respawn at a different location")
	second.close()
	world._return_to_main_menu()
	assert(world.multiplayer_page.visible, "Leaving multiplayer did not return to lobby")
	world.queue_free()
	await process_frame
	print("Multiplayer smoke test passed: lobby, tokens, screams, respawn, meat, AI snapshots, and return")
	quit()
