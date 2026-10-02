extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world._dismiss_splash(true)
	var tile = world.landing_page.find_child("MultiplayerTile", true, false)
	assert(tile != null and tile.disabled == false, "Multiplayer landing tile is missing")
	world._show_multiplayer_page()
	assert(world.multiplayer_page.visible and world.multiplayer_dino_cards.size() == 7, "Multiplayer dinosaur selection is incomplete")
	world.multiplayer_settings.set_value("server", "url", "wss://games.example.org:9443/")
	world.multiplayer_settings.erase_section_key("server", "host")
	world.multiplayer_settings.erase_section_key("server", "port")
	world.multiplayer_settings.erase_section_key("server", "secure")
	var migrated: Dictionary = world._saved_multiplayer_connection()
	assert(migrated["host"] == "games.example.org" and int(migrated["port"]) == 9443 and bool(migrated["secure"]), "Previously saved server URL was not migrated")
	world._select_dino("stegosaurus")
	world.multiplayer_host_input.text = "127.0.0.1"
	world.multiplayer_port_input.text = "0"
	world._connect_multiplayer()
	assert(world.multiplayer_status_label.text == world._t("menu.server_port_invalid"), "Invalid server port was accepted")
	world.multiplayer_port_input.text = "8765"
	world.multiplayer_secure_checkbox.button_pressed = false
	world._connect_multiplayer()
	assert(world.multiplayer_settings.get_value("server", "host") == "127.0.0.1", "Server IP was not saved")
	assert(int(world.multiplayer_settings.get_value("server", "port")) == 8765, "Server port was not saved")
	assert(world.multiplayer_settings.get_value("server", "url") == "ws://127.0.0.1:8765/", "Host and port did not produce the expected WebSocket URL")
	for frame in 900:
		await process_frame
		if world.multiplayer_active and is_instance_valid(world.player):
			break
	assert(world.multiplayer_active, "Godot client did not join the Python server")
	assert(world.selected_map_theme == "grassland" and world.map_seed == 424242, "Server map configuration was not applied")
	assert(world.player.dino_id == "stegosaurus", "Selected multiplayer dinosaur was not used")
	assert(world.generated_dinosaurs.is_empty() or world.world_root.find_child("WildDinosaurs", false, false) == null, "Unsynchronized wildlife was created")
	var second := WebSocketPeer.new()
	assert(second.connect_to_url("ws://127.0.0.1:8765/") == OK, "Second client could not connect")
	for frame in 180:
		second.poll()
		if second.get_ready_state() == WebSocketPeer.STATE_OPEN:
			break
		await process_frame
	assert(second.get_ready_state() == WebSocketPeer.STATE_OPEN, "Second client did not open")
	second.send_text(JSON.stringify({"type": "hello", "dino": "trex"}))
	var second_spawn := Vector3.ZERO
	for frame in 240:
		second.poll()
		while second.get_available_packet_count() > 0:
			var message = JSON.parse_string(second.get_packet().get_string_from_utf8())
			if message is Dictionary and message.get("type") == "welcome":
				var spawn: Dictionary = message["spawn"]
				second_spawn = Vector3(float(spawn["x"]), float(spawn["y"]), float(spawn["z"]))
		if world.remote_players.size() == 1 and second_spawn.length() > 0.0:
			break
		await process_frame
	assert(world.remote_players.size() == 1, "The second player did not appear in the first player's world")
	var remote = world.remote_players.values()[0]
	assert(remote.dino_id == "trex" and remote.find_child("RemoteModel", false, false) != null, "The remote dinosaur was not rendered")
	second.send_text(JSON.stringify({"type": "state", "x": second_spawn.x + 1.0, "y": second_spawn.y, "z": second_spawn.z, "yaw": 0.4, "animation": "walk"}))
	for frame in 120:
		second.poll()
		await process_frame
		if absf(remote.target_position.x - second_spawn.x - 1.0) < 0.01:
			break
	assert(absf(remote.target_position.x - second_spawn.x - 1.0) < 0.01, "Remote movement was not synchronized")
	second.close()
	for frame in 120:
		await process_frame
		if world.remote_players.is_empty():
			break
	assert(world.remote_players.is_empty(), "Disconnected remote player remained in the map")
	world._return_to_main_menu()
	assert(world.multiplayer_page.visible and world.multiplayer_client.socket == null, "Leaving multiplayer did not disconnect")
	print("Multiplayer smoke test passed: setup, join, shared map, peer movement, and leave")
	world.queue_free()
	await process_frame
	quit()
