# Dinos4Helena multiplayer server

This server runs independently of Godot on a separate computer. It uses Python 3.10 or newer with no third-party Python packages. OpenSSL must be installed on the host for the initial automatic certificate generation. One server process hosts up to 16 independent sessions, each with a grassland, desert, winter, or volcano map and up to ten players.

## Run on a local network

1. Copy the `server` folder to the host computer. Check that `python3 --version` reports Python 3.10 or newer and that `openssl version` works.
2. From that folder, start the server:

   ```sh
   python3 server.py --host 0.0.0.0 --port 8765 --seed 424242
   ```

   The first launch creates `certs/server.crt` and `certs/server.key` next to the script, then serves encrypted `wss://` connections. Later launches reuse the same keypair. The private key is mode `0600` and the `certs` directory is ignored by Git. Keep the key private and back up both files together. `0.0.0.0` means listen on all network interfaces; it is **not** the address players enter in the game. The legacy test world uses the six-digit `--seed` value; each newly created session receives its own six-digit seed. To accept connections only from the host computer, use `--host 127.0.0.1`.
3. Find the host computer's LAN IPv4 address in its network settings (for example `192.168.1.50`). Allow incoming **TCP 8765** in its firewall. The server and devices must be able to reach each other on the same network.
4. On each device, open **Configuration** at the bottom-left of the start screen. The default is `92.205.18.100:8765` with TLS and self-signed certificates enabled. For your own server, enter its IP or DNS name in **Server IP / Host** and enter `8765` as **Port**. Keep **Secure connection** and **Allow self-signed certificate** checked for the automatically generated certificate. Use **Test Server Connection** to check the current fields without saving; it briefly joins and leaves the game. Save the settings, then open **Multiplayer** to see current sessions. Choose **Join** and select a dinosaur, name, and color, or choose **Create Session** to select a map theme as well. Do not enter `0.0.0.0` or `127.0.0.1` on a different device; those addresses refer to that device itself.

The app saves the host, port, and TLS settings locally for the next session. If a session already has ten players, its Join button is disabled. Empty sessions are removed automatically; restarting the server clears all sessions.

## Check a server setup

Run this from the **device or computer whose connection you want to test**, using the same host and port entered in the app. Copy `check_server.py` there; it needs only Python 3.10 or newer, not Godot or third-party packages:

```sh
python3 check_server.py wss://192.168.1.50:8765/ --allow-self-signed
```

For a certificate trusted by the operating system, omit `--allow-self-signed`. To verify a self-signed certificate without disabling identity checks, use `--ca-cert /path/to/server.crt` and connect using a host name or IP included in that certificate. For a server started with `--no-tls`, use `ws://192.168.1.50:8765/` without either TLS option. You can also set `--dino trex` and `--timeout 10`.

The script performs the TLS connection, WebSocket upgrade, and actual game join. It prints the map, seed, player ID, other-player count, and a TLS status on success; it exits with status `1` and a diagnostic on failure. A full server rejects the test join. The check briefly occupies one player slot and then disconnects. `--allow-self-signed` disables certificate **and host-name** verification for this check, just like the corresponding app option; use it only for a server you trust by other means. Run it from another network if you need to check Internet reachability rather than only local access.

## Host on the Internet

Use a DNS name pointing to the server's public IP. Allow the chosen TCP port in the host and cloud firewalls. If the server sits behind a home router, forward that TCP port to the host's LAN IP. A private LAN address such as `192.168.x.x` will not work from outside the LAN.

The automatically generated certificate also works over the Internet when players explicitly allow self-signed certificates. That option encrypts traffic but does **not** verify that the remote server is the intended one; an attacker could impersonate it. For a public server, use a certificate trusted by the players' devices and leave **Allow self-signed certificate** unchecked. Pass your own certificate and key to the server:

```sh
python3 server.py --host 0.0.0.0 --port 8765 --seed 424242 --cert /path/to/cert.pem --key /path/to/key.pem
```

In the app's start-screen **Configuration**, enter the certificate's DNS name as **Server IP / Host**, the chosen port, and check **Secure connection (TLS / wss)**. A TLS reverse proxy is also possible; forward WebSocket traffic on `/` to the Python server and enter the proxy's public port in the app. This first version has no accounts or access control. Use a private network or add authentication before exposing a server intended only for invited players.

To put the host's address in a newly generated certificate, add `--cert-host 192.168.1.50` or `--cert-host game.example.org` on its **first** run. Existing certificates are deliberately reused; changing `--cert-host` later does not replace them. To generate a new pair, first stop the server and safely move both existing files out of `certs/`, then start it again. Clients that explicitly allow self-signed certificates do not check the certificate's host name.

Plain `ws://` is still available for a private test network via `--no-tls`; in that case, uncheck both TLS options in the app. `--cert-dir /another/private/path` changes where the automatic pair is stored.

## Keep it running on Linux (optional)

Create a systemd service with paths and user adjusted for your installation:

```ini
[Unit]
Description=Dinos4Helena multiplayer server
After=network-online.target

[Service]
User=YOUR_USER
WorkingDirectory=/opt/dinos4helena/server
ExecStart=/usr/bin/python3 /opt/dinos4helena/server/server.py --host 0.0.0.0 --port 8765 --seed 424242
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Save it as `/etc/systemd/system/dinos4helena.service`, then run `sudo systemctl daemon-reload` and `sudo systemctl enable --now dinos4helena`. Inspect logs with `journalctl -u dinos4helena -f`. The service user needs write access to the certificate directory on first start and read access afterward. Add `--cert` and `--key` to `ExecStart` if you provide a trusted certificate instead of using the generated one.

## Troubleshooting

- **Cannot reach server:** Check that the server process is running, host/IP and port match, TCP traffic is allowed, and both devices can reach each other. Use the host's LAN IP on a LAN, not `127.0.0.1` from another device.
- **TLS connection fails:** Check that **Secure connection** is on for the default server, and that **Allow self-signed certificate** is on for its generated certificate. For a trusted certificate, leave the second option off and check that its host name matches.
- **OpenSSL not found:** Install the OpenSSL command-line program, or supply an existing certificate and key with `--cert` and `--key`.
- **World full:** Ten clients are already connected; wait for one to leave.

## Current game rules and protocol

The server assigns a player ID and spawn slot, distributes the shared seed, relays position, rotation, and action animation, removes disconnected players, and validates proximity, facing, cooldown, and species for player attacks. Same-species attacks are ignored. The map is generated locally from the server seed. Each session has its own seeded grassland, desert, winter, or volcano map and holds up to 10 players; the server allows up to 16 simultaneous sessions. The first player in a session simulates wildlife with the single-player AI and sends NPC snapshots through the server. The server validates player-to-NPC attacks and NPC-to-player damage; if that player leaves, AI authority moves to another player. Eggs and power-up tokens remain absent from multiplayer; food plants behave locally. Sessions disappear when the last player leaves.

The protocol is JSON over WebSocket text frames. A new client sends `{"type":"list"}` and receives a `sessions` list, then sends `{"type":"create","map":"desert","dino":"triceratops","name":"Helena","color":"#f47ac2"}` or `{"type":"join","session":1,"dino":"trex","name":"Dad","color":"#4ecdc4"}`. The legacy `hello` request still joins a shared grassland test world for older clients and the setup checker. Names must be 1–20 printable characters; colors must be one of the eight choices in the game. For compatibility with older clients and the setup checker, omitted identity fields receive a generated player name and the default blue color. The server replies with `welcome` (ID, seed, spawn, current roster), broadcasts `joined` and `left`, relays `state`, and broadcasts `hit` events with server-computed health. Spawn, roster, join, and state player objects include the name and color. Clients send `state`, `attack`, or `scream` after joining. Malformed, oversized, unmasked, or fragmented frames are rejected, and idle clients are dropped after 30 seconds. Deploy this updated server together with the updated game for session browsing and synchronized wildlife.
