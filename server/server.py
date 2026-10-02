#!/usr/bin/env python3
"""Standalone asyncio WebSocket server for one Dinos4Helena grassland world.

Uses the Python standard library at runtime and OpenSSL to create a TLS
certificate on first launch. See README.md for protocol and hosting.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import binascii
import hashlib
import ipaddress
import json
import math
import os
import secrets
import shutil
import ssl
import struct
import subprocess
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path


SPECIES = {
    "trex": (150, 8.0, 15), "spinosaurus": (200, 8.2, 20),
    "triceratops": (180, 6.0, 8), "stegosaurus": (170, 4.8, 9),
    "velociraptor": (85, 9.0, 5), "parasaurolophus": (105, 7.0, 4),
    "apatosaurus": (210, 4.5, 10),
}
MAX_PLAYERS = 10
MAX_MESSAGE_BYTES = 4096
WORLD_LIMIT = 194.0
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
DEFAULT_CERT_DIR = Path(__file__).resolve().parent / "certs"


class ProtocolError(Exception):
    pass


def ensure_tls_certificates(cert_dir: Path, certificate_host: str = "localhost") -> tuple[Path, Path]:
    """Create a persistent self-signed keypair on first run; never overwrite it."""
    cert_dir = Path(cert_dir)
    certificate = cert_dir / "server.crt"
    key = cert_dir / "server.key"
    if certificate.exists() != key.exists():
        raise ValueError(f"Incomplete TLS keypair in {cert_dir}; restore the missing file")
    if certificate.exists():
        return certificate, key
    if not certificate_host or any(char not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:" for char in certificate_host):
        raise ValueError("--cert-host must be an IP address or DNS name")
    try:
        ipaddress.ip_address(certificate_host)
        subject_name = f"IP:{certificate_host}"
    except ValueError:
        if ":" in certificate_host:
            raise ValueError("--cert-host must be an IP address or DNS name") from None
        subject_name = f"DNS:{certificate_host}"
    openssl = shutil.which("openssl")
    if openssl is None:
        raise RuntimeError("OpenSSL is required once to generate a self-signed certificate; install it or pass --cert and --key")
    cert_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Temporary files prevent a failed OpenSSL run from leaving a partial pair.
    with tempfile.TemporaryDirectory(dir=cert_dir) as temporary:
        temp_cert = Path(temporary) / "server.crt"
        temp_key = Path(temporary) / "server.key"
        subprocess.run([
            openssl, "req", "-x509", "-newkey", "rsa:3072", "-sha256",
            "-nodes", "-days", "365", "-keyout", str(temp_key),
            "-out", str(temp_cert), "-subj", f"/CN={certificate_host}",
            "-addext", f"subjectAltName=DNS:localhost,IP:127.0.0.1,{subject_name}",
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        os.chmod(temp_key, 0o600)
        os.chmod(temp_cert, 0o644)
        temp_key.replace(key)
        temp_cert.replace(certificate)
    print(f"Created self-signed TLS certificate: {certificate}", flush=True)
    return certificate, key


async def read_frame(reader: asyncio.StreamReader) -> tuple[int, bytes]:
    head = await reader.readexactly(2)
    opcode = head[0] & 0x0F
    if not head[0] & 0x80 or not head[1] & 0x80:
        raise ProtocolError("Only complete masked client frames are supported")
    size = head[1] & 0x7F
    if size == 126:
        size = struct.unpack("!H", await reader.readexactly(2))[0]
    elif size == 127:
        size = struct.unpack("!Q", await reader.readexactly(8))[0]
    if size > MAX_MESSAGE_BYTES:
        raise ProtocolError("Message is too large")
    mask = await reader.readexactly(4)
    payload = await reader.readexactly(size)
    return opcode, bytes(value ^ mask[index % 4] for index, value in enumerate(payload))


def make_frame(payload: bytes, opcode: int = 1) -> bytes:
    size = len(payload)
    if size < 126:
        header = bytes((0x80 | opcode, size))
    elif size < 65536:
        header = bytes((0x80 | opcode, 126)) + struct.pack("!H", size)
    else:
        header = bytes((0x80 | opcode, 127)) + struct.pack("!Q", size)
    return header + payload


@dataclass
class Player:
    identifier: int
    writer: asyncio.StreamWriter
    dino: str
    x: float
    y: float
    z: float
    yaw: float = 0.0
    animation: str = "idle"
    health: int = 100
    last_state: float = field(default_factory=time.monotonic)
    last_attack: float = 0.0

    def public(self) -> dict:
        return {
            "id": self.identifier, "dino": self.dino,
            "x": round(self.x, 3), "y": round(self.y, 3), "z": round(self.z, 3),
            "yaw": round(self.yaw, 4), "animation": self.animation,
            "health": self.health,
        }


class GameServer:
    def __init__(self, seed: int = 424242, limit: int = MAX_PLAYERS):
        self.seed = seed
        self.limit = limit
        self.players: dict[int, Player] = {}
        self.lock = asyncio.Lock()

    async def send(self, writer: asyncio.StreamWriter, message: dict) -> None:
        writer.write(make_frame(json.dumps(message, separators=(",", ":")).encode()))
        await writer.drain()

    async def broadcast(self, message: dict, exclude: int | None = None) -> None:
        data = make_frame(json.dumps(message, separators=(",", ":")).encode())
        for player in tuple(self.players.values()):
            if player.identifier != exclude and not player.writer.is_closing():
                player.writer.write(data)
        await asyncio.gather(
            *(player.writer.drain() for player in tuple(self.players.values())
              if player.identifier != exclude and not player.writer.is_closing()),
            return_exceptions=True,
        )

    def spawn(self, slot: int) -> tuple[float, float, float]:
        angle = slot * math.tau / self.limit
        return round(math.cos(angle) * 12, 3), 0.1, round(math.sin(angle) * 12, 3)

    async def handshake(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        request = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
        if len(request) > 8192:
            raise ProtocolError("HTTP request is too large")
        lines = request.decode("latin-1").split("\r\n")
        if lines[0] != "GET / HTTP/1.1":
            raise ProtocolError("Expected a WebSocket GET on /")
        headers = {}
        for line in lines[1:]:
            if ":" in line:
                key, value = line.split(":", 1)
                headers[key.lower()] = value.strip()
        key = headers.get("sec-websocket-key", "")
        if (headers.get("upgrade", "").lower() != "websocket"
                or "upgrade" not in headers.get("connection", "").lower()
                or len(base64.b64decode(key, validate=True)) != 16):
            raise ProtocolError("Invalid WebSocket upgrade")
        accept = base64.b64encode(hashlib.sha1((key + GUID).encode()).digest()).decode()
        writer.write((
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
            f"Connection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n"
        ).encode())
        await writer.drain()

    async def handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        player: Player | None = None
        try:
            await self.handshake(reader, writer)
            opcode, payload = await asyncio.wait_for(read_frame(reader), 10)
            if opcode != 1:
                raise ProtocolError("Expected a hello message")
            hello = json.loads(payload)
            if (not isinstance(hello, dict) or hello.get("type") != "hello"
                    or not isinstance(hello.get("dino"), str) or hello["dino"] not in SPECIES):
                await self.send(writer, {"type": "rejected", "reason": "invalid_dinosaur"})
                return
            async with self.lock:
                if len(self.players) >= self.limit:
                    await self.send(writer, {"type": "rejected", "reason": "full"})
                    return
                occupied = {getattr(p, "slot", -1) for p in self.players.values()}
                slot = next(index for index in range(self.limit) if index not in occupied)
                x, y, z = self.spawn(slot)
                identifier = secrets.randbits(53)
                while identifier in self.players:
                    identifier = secrets.randbits(53)
                player = Player(identifier, writer, hello["dino"], x, y, z,
                                health=SPECIES[hello["dino"]][0])
                player.slot = slot
                roster = [member.public() for member in self.players.values()]
                self.players[identifier] = player
                await self.send(writer, {
                    "type": "welcome", "id": identifier, "seed": self.seed,
                    "map": "grassland", "limit": self.limit, "spawn": player.public(),
                    "players": roster,
                })
                await self.broadcast({"type": "joined", "player": player.public()}, identifier)
            while True:
                opcode, payload = await asyncio.wait_for(read_frame(reader), 30)
                if opcode == 8:
                    break
                if opcode == 9:
                    writer.write(make_frame(payload, 10))
                    await writer.drain()
                    continue
                if opcode != 1:
                    raise ProtocolError("Only text messages are accepted")
                message = json.loads(payload)
                if not isinstance(message, dict):
                    continue
                kind = message.get("type")
                if kind == "state":
                    await self.update_state(player, message)
                elif kind == "attack":
                    await self.attack(player)
                elif kind == "scream":
                    await self.broadcast({"type": "scream", "id": player.identifier}, player.identifier)
        except (asyncio.IncompleteReadError, ConnectionError, TimeoutError):
            pass
        except (ProtocolError, ValueError, UnicodeError, TypeError, binascii.Error) as error:
            print(f"Client rejected: {error}")
        finally:
            if player is not None:
                async with self.lock:
                    self.players.pop(player.identifier, None)
                    await self.broadcast({"type": "left", "id": player.identifier})
            writer.close()
            try:
                await writer.wait_closed()
            except ConnectionError:
                pass

    async def update_state(self, player: Player, message: dict) -> None:
        try:
            x, y, z, yaw = (float(message[key]) for key in ("x", "y", "z", "yaw"))
        except (KeyError, ValueError, TypeError):
            return
        if not all(map(math.isfinite, (x, y, z, yaw))):
            return
        if abs(x) > WORLD_LIMIT or abs(z) > WORLD_LIMIT or y < -5 or y > 35:
            return
        now = time.monotonic()
        elapsed = min(now - player.last_state, 1.0)
        max_distance = SPECIES[player.dino][1] * elapsed * 1.7 + 3.0
        if math.dist((x, z), (player.x, player.z)) > max_distance:
            return
        player.x, player.y, player.z, player.yaw = x, y, z, yaw
        player.last_state = now
        animation = message.get("animation", "idle")
        player.animation = animation if animation in ("idle", "walk", "run", "attack", "eat", "scream") else "idle"
        await self.broadcast({"type": "state", "player": player.public()}, player.identifier)

    async def attack(self, attacker: Player) -> None:
        now = time.monotonic()
        if now - attacker.last_attack < 1.0 or attacker.health <= 0:
            return
        attacker.last_attack = now
        forward = (-math.sin(attacker.yaw), -math.cos(attacker.yaw))
        target = None
        nearest = 5.0
        for candidate in self.players.values():
            if candidate.identifier == attacker.identifier or candidate.dino == attacker.dino or candidate.health <= 0:
                continue
            dx, dz = candidate.x - attacker.x, candidate.z - attacker.z
            distance = math.hypot(dx, dz)
            if 0.01 < distance < nearest and (forward[0] * dx + forward[1] * dz) / distance > 0.2:
                target, nearest = candidate, distance
        if target is None:
            return
        target.health = max(0, target.health - SPECIES[attacker.dino][2] * 3)
        await self.broadcast({"type": "hit", "attacker": attacker.identifier,
                              "target": target.identifier, "health": target.health})


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--seed", type=int, default=424242)
    parser.add_argument("--cert", help="TLS certificate for wss://")
    parser.add_argument("--key", help="TLS private key for wss://")
    parser.add_argument("--cert-dir", type=Path, default=DEFAULT_CERT_DIR,
                        help="directory for the automatically generated TLS keypair")
    parser.add_argument("--cert-host", default="localhost",
                        help="IP address or DNS name to include in a new certificate")
    parser.add_argument("--no-tls", action="store_true", help="serve unencrypted ws:// instead of wss://")
    args = parser.parse_args()
    if not 100000 <= args.seed <= 999999:
        parser.error("--seed must be a six-digit world seed")
    if bool(args.cert) != bool(args.key):
        parser.error("--cert and --key must be supplied together")
    if args.no_tls and args.cert:
        parser.error("--no-tls cannot be used with --cert and --key")
    context = None
    if not args.no_tls:
        cert_path, key_path = (Path(args.cert), Path(args.key)) if args.cert else ensure_tls_certificates(args.cert_dir, args.cert_host)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(cert_path, key_path)
    game = GameServer(args.seed)
    server = await asyncio.start_server(game.handle, args.host, args.port, ssl=context)
    print(f"Dinos4Helena server listening on {'wss' if context else 'ws'}://{args.host}:{args.port}/; seed {args.seed}; max {MAX_PLAYERS}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
