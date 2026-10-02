# Dinos4Helena multiplayer server

This server runs independently of Godot on a separate computer. It uses Python 3.10 or newer with no third-party Python packages. OpenSSL must be installed on the host for the initial automatic certificate generation. One server process hosts one grassland map for up to ten players.

## Run on a local network

1. Copy the `server` folder to the host computer. Check that `python3 --version` reports Python 3.10 or newer and that `openssl version` works.
2. From that folder, start the server:

   ```sh
   python3 server.py --host 0.0.0.0 --port 8765 --seed 424242
   ```

   The first launch creates `certs/server.crt` and `certs/server.key` next to the script, then serves encrypted `wss://` connections. Later launches reuse the same keypair. The private key is mode `0600` and the `certs` directory is ignored by Git. Keep the key private and back up both files together. `0.0.0.0` means listen on all network interfaces; it is **not** the address players enter in the game. The seed must have six digits; all players receive the same seed from the server. To accept connections only from the host computer, use `--host 127.0.0.1`.
3. Find the host computer's LAN IPv4 address in its network settings (for example `192.168.1.50`). Allow incoming **TCP 8765** in its firewall. The server and devices must be able to reach each other on the same network.
4. On each device, open **Multiplayer**, choose a dinosaur, and enter the host computer's IP or DNS name in **Server IP / Host**. Enter `8765` as **Port**, check **Secure connection**, and check **Allow self-signed certificate**. Tap **Connect and Play**. Do not enter `0.0.0.0` or `127.0.0.1` on a different device; those addresses refer to that device itself.

The app saves the host, port, and secure setting locally for the next session. If the server rejects an eleventh player, the app shows a full-world message. Restarting the server starts a new session.

## Host on the Internet

Use a DNS name pointing to the server's public IP. Allow the chosen TCP port in the host and cloud firewalls. If the server sits behind a home router, forward that TCP port to the host's LAN IP. A private LAN address such as `192.168.x.x` will not work from outside the LAN.

The automatically generated certificate also works over the Internet when players explicitly allow self-signed certificates. That option encrypts traffic but does **not** verify that the remote server is the intended one; an attacker could impersonate it. For a public server, use a certificate trusted by the players' devices and leave **Allow self-signed certificate** unchecked. Pass your own certificate and key to the server:

```sh
python3 server.py --host 0.0.0.0 --port 8765 --seed 424242 --cert /path/to/cert.pem --key /path/to/key.pem
```

In the app, enter the certificate's DNS name as **Server IP / Host**, the chosen port, and check **Secure connection (TLS / wss)**. A TLS reverse proxy is also possible; forward WebSocket traffic on `/` to the Python server and enter the proxy's public port in the app. This first version has no accounts or access control. Use a private network or add authentication before exposing a server intended only for invited players.

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

The server assigns a player ID and spawn slot, distributes the shared seed, relays position, rotation, and action animation, removes disconnected players, and validates proximity, facing, cooldown, and species for player attacks. Same-species attacks are ignored. The map is generated locally from the server seed. Wildlife, eggs, and power-up tokens are absent from multiplayer because they are not yet synchronized; food plants still behave locally.

The protocol is JSON over WebSocket text frames. Clients first send `{"type":"hello","dino":"triceratops"}`. The server replies with `welcome` (ID, seed, spawn, current roster), broadcasts `joined` and `left`, relays `state`, and broadcasts `hit` events with server-computed health. Clients send `state`, `attack`, or `scream` after joining. Malformed, oversized, unmasked, or fragmented frames are rejected, and idle clients are dropped after 30 seconds.
