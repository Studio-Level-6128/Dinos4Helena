# Dinos4Helena multiplayer server

The server runs independently of Godot and uses only Python 3.10+ standard-library modules. It hosts one grassland world with a fixed six-digit seed and accepts at most ten simultaneous players.

Run it on the host machine:

```sh
python3 server.py --host 0.0.0.0 --port 8765 --seed 424242
```

Open TCP port 8765 in the host firewall. In the game's Multiplayer page, enter `ws://HOSTNAME:8765/`, select a dinosaur, and connect. The app remembers the address in its local user settings. The host can change the port and seed at startup. A server restart resets the session.

For a public Internet server, use TLS. Either pass `--cert certificate.pem --key private-key.pem` and connect with `wss://HOSTNAME:8765/`, or put a TLS reverse proxy in front of the plain WebSocket listener. Use an authenticated/private network if you need to restrict who can join; this first version has no accounts.

The server assigns a player ID and spawn slot, distributes the shared seed, relays position/rotation/action animation at roughly ten updates per second, removes disconnected players, and validates proximity, facing, cooldown, and species for player attacks. An eleventh connection receives `{"type":"rejected","reason":"full"}`. Players can see each other, move around the shared map, scream, and fight other species. Same-species attacks are ignored. The map is generated locally from the same server seed. Wildlife, eggs, and power-up tokens are absent from multiplayer because their simulation is not yet server synchronized; food plants still behave locally.

The protocol is JSON in standard WebSocket text frames. Clients first send `{"type":"hello","dino":"triceratops"}`. The server replies with `welcome` (ID, seed, spawn, current roster), broadcasts `joined`/`left`, relays `state` snapshots, and broadcasts `hit` events with server-computed health. Clients send `state`, `attack`, or `scream` after joining. The server rejects oversized, malformed, unmasked, or fragmented frames and drops idle clients after 30 seconds. No third-party Python package is required.
